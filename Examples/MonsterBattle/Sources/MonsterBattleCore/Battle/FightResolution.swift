import Foundation

/// Executes a single Fight action: pre-move status, accuracy, damage,
/// multi-hit expansion, and secondary-effect application.
enum FightResolution {

    private enum Constants {
        static let multiHitFallbackMax: Int = 5
    }

    static func perform(state: inout BattleState, attacker: BattleSideID, slotIndex: Int) {
        // Fetch combatants and confirm the active attacker hasn't been KO'd
        // earlier in the same turn.
        let attackerID = currentID(attacker: attacker, state: state)
        var attackerCombatant = combatant(side: attacker, state: state)
        guard !attackerCombatant.isFainted else { return }

        // Pre-move status check.
        if let skip = rollPreMoveSkip(state: &state, combatant: &attackerCombatant) {
            commit(side: attacker, combatant: attackerCombatant, state: &state)
            state.appendEvent(.skippedTurn(monsterID: attackerID, reason: skip))
            return
        }
        commit(side: attacker, combatant: attackerCombatant, state: &state)

        // Resolve the move slot.
        guard attackerCombatant.monster.moves.indices.contains(slotIndex) else { return }
        var slot = attackerCombatant.monster.moves[slotIndex]
        guard let move = MoveDex.byID[slot.moveID] else { return }

        // PP deduction (but allow zero-PP moves to still fire in fallback).
        if slot.currentPP > 0 {
            slot.currentPP -= 1
            attackerCombatant.monster.moves[slotIndex] = slot
            commit(side: attacker, combatant: attackerCombatant, state: &state)
        }

        state.appendEvent(.moveUsed(attackerID: attackerID, move: move.name))

        // Accuracy check.
        var hit = false
        state.withRNG { rng in
            hit = AccuracyCheck.hits(
                move: move,
                attacker: attackerCombatant,
                defender: combatant(side: attacker.other, state: state),
                rng: &rng
            )
        }
        if !hit {
            state.appendEvent(.moveMissed(attackerID: attackerID))
            return
        }

        // Multi-hit expansion: pick hit count once, each hit rolls fresh damage.
        let hitCount = multiHitCount(for: move, state: &state)

        for _ in 0..<max(1, hitCount) {
            performSingleHit(state: &state, attacker: attacker, move: move)
            if state.outcome != .ongoing { return }
            if combatant(side: attacker.other, state: state).isFainted { break }
            if combatant(side: attacker, state: state).isFainted { break }
        }

        applySecondaryEffect(state: &state, attacker: attacker, move: move)
    }

    // MARK: - Pre-move status

    private static func rollPreMoveSkip(
        state: inout BattleState,
        combatant: inout Combatant
    ) -> SkipReason? {
        switch combatant.monster.status {
        case .freeze:
            // Chance to thaw on its own.
            var thawed = false
            state.withRNG { rng in
                let roll = Double(randomInt(below: 1_000_000, using: &rng)) / 1_000_000.0
                thawed = roll < combatant.monster.status.thawProbability
            }
            if thawed {
                let cured: StatusCondition = .freeze
                combatant.monster.status = .none
                state.appendEvent(.statusCured(monsterID: combatant.monster.id, status: cured))
                return nil
            }
            return .frozen
        case .sleep:
            if combatant.sleepTurnsRemaining > 0 {
                combatant.sleepTurnsRemaining -= 1
            }
            if combatant.sleepTurnsRemaining <= 0 {
                combatant.monster.status = .none
                state.appendEvent(.statusCured(monsterID: combatant.monster.id, status: .sleep))
                return nil
            }
            return .asleep(turnsLeft: combatant.sleepTurnsRemaining)
        case .paralyze:
            var skipped = false
            state.withRNG { rng in
                let roll = Double(randomInt(below: 1_000_000, using: &rng)) / 1_000_000.0
                skipped = roll < StatusCondition.paralyze.skipTurnProbability
            }
            return skipped ? .paralyzed : nil
        default:
            return nil
        }
    }

    // MARK: - Single hit

    private static func performSingleHit(state: inout BattleState, attacker: BattleSideID, move: Move) {
        let attackerCombatant = combatant(side: attacker, state: state)
        var defenderCombatant = combatant(side: attacker.other, state: state)
        let defenderID = defenderCombatant.monster.id

        var result = DamageResult(damage: 0, effectiveness: 1.0, critical: false)
        state.withRNG { rng in
            result = DamageCalculator.compute(
                attacker: attackerCombatant,
                defender: defenderCombatant,
                move: move,
                rng: &rng
            )
        }

        if result.damage > 0 {
            let actual = min(result.damage, defenderCombatant.monster.currentHP)
            defenderCombatant.monster.currentHP -= actual
            commit(side: attacker.other, combatant: defenderCombatant, state: &state)
            state.appendEvent(.damageDealt(
                defenderID: defenderID,
                amount: actual,
                effectiveness: Effectiveness(multiplier: result.effectiveness),
                critical: result.critical
            ))
            if defenderCombatant.isFainted {
                state.appendEvent(.fainted(monsterID: defenderID))
            }
        } else if result.effectiveness == 0 && move.category != .status {
            state.appendEvent(.damageDealt(
                defenderID: defenderID,
                amount: 0,
                effectiveness: .noEffect,
                critical: false
            ))
        }

        // Recoil fires even on partial hits of a multi-hit.
        if let effect = move.effect,
           case .recoil(let fraction) = effect.kind,
           result.damage > 0 {
            var attackerCopy = combatant(side: attacker, state: state)
            let recoil = max(1, Int(Double(result.damage) * max(0, fraction)))
            let applied = min(recoil, attackerCopy.monster.currentHP)
            attackerCopy.monster.currentHP -= applied
            commit(side: attacker, combatant: attackerCopy, state: &state)
            state.appendEvent(.statusDamage(
                monsterID: attackerCopy.monster.id,
                status: .none,
                amount: applied
            ))
            if attackerCopy.isFainted {
                state.appendEvent(.fainted(monsterID: attackerCopy.monster.id))
            }
        }
    }

    // MARK: - Secondary effects

    private static func applySecondaryEffect(state: inout BattleState, attacker: BattleSideID, move: Move) {
        guard let effect = move.effect else { return }
        // Multi-hit was already resolved at a higher level; skip here.
        if case .multiHit = effect.kind { return }
        // Recoil fires per-hit, not as a secondary.
        if case .recoil = effect.kind { return }

        // Chance roll.
        var fires = false
        state.withRNG { rng in
            let roll = randomInt(in: 1...100, using: &rng)
            fires = roll <= max(0, min(100, effect.chance))
        }
        guard fires else { return }

        switch effect.kind {
        case .applyStatus(let status):
            applyStatus(state: &state, to: attacker.other, status: status)
        case .statChange(let target, let change):
            let targetSide: BattleSideID = (target == .user) ? attacker : attacker.other
            applyStatChange(state: &state, to: targetSide, change: change)
        case .heal(let fraction):
            applyHeal(state: &state, to: attacker, fraction: fraction)
        case .recoil, .multiHit:
            break
        }
    }

    private static func applyStatus(state: inout BattleState, to side: BattleSideID, status: StatusCondition) {
        var target = combatant(side: side, state: state)
        guard !target.isFainted else { return }
        // Don't overwrite an existing status.
        guard target.monster.status == .none else { return }
        target.monster.status = status
        if status == .sleep {
            var turns = 1
            state.withRNG { rng in
                turns = randomInt(in: status.sleepTurnRange, using: &rng)
            }
            target.sleepTurnsRemaining = max(1, turns)
        }
        commit(side: side, combatant: target, state: &state)
        state.appendEvent(.statusApplied(monsterID: target.monster.id, status: status))
    }

    private static func applyStatChange(state: inout BattleState, to side: BattleSideID, change: StatChange) {
        var target = combatant(side: side, state: state)
        let before = target.stages.stage(for: change.stat)
        target.stages.apply(change)
        let after = target.stages.stage(for: change.stat)
        let actualDelta = after - before
        commit(side: side, combatant: target, state: &state)
        if actualDelta != 0 {
            state.appendEvent(.statChanged(
                monsterID: target.monster.id,
                stat: change.stat,
                delta: actualDelta
            ))
        }
    }

    private static func applyHeal(state: inout BattleState, to side: BattleSideID, fraction: Double) {
        var target = combatant(side: side, state: state)
        guard !target.isFainted else { return }
        let maxHP = target.maxHP
        let amount = max(1, Int(Double(maxHP) * max(0, fraction)))
        let actual = min(amount, maxHP - target.monster.currentHP)
        if actual <= 0 { return }
        target.monster.currentHP += actual
        commit(side: side, combatant: target, state: &state)
        state.appendEvent(.healed(monsterID: target.monster.id, amount: actual))
    }

    // MARK: - Multi-hit helper

    private static func multiHitCount(for move: Move, state: inout BattleState) -> Int {
        guard let effect = move.effect,
              case .multiHit(let lower, let upper) = effect.kind else {
            return 1
        }
        let low = max(1, min(lower, upper))
        let high = max(low, max(upper, 1))
        var picked = low
        state.withRNG { rng in
            picked = randomInt(in: low...min(high, Constants.multiHitFallbackMax), using: &rng)
        }
        return picked
    }

    // MARK: - Side helpers

    private static func combatant(side: BattleSideID, state: BattleState) -> Combatant {
        switch side {
        case .player:   return state.player.combatant
        case .opponent: return state.opponent.combatant
        }
    }

    private static func commit(side: BattleSideID, combatant: Combatant, state: inout BattleState) {
        switch side {
        case .player:   state.player.combatant = combatant
        case .opponent: state.opponent.combatant = combatant
        }
    }

    private static func currentID(attacker: BattleSideID, state: BattleState) -> UUID {
        combatant(side: attacker, state: state).monster.id
    }
}

extension BattleSideID {
    /// The opposing side.
    var other: BattleSideID {
        switch self {
        case .player:   return .opponent
        case .opponent: return .player
        }
    }
}
