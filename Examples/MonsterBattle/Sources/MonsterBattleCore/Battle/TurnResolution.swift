import Foundation

/// Identifies which side an action originated from. Used internally to
/// keep the turn-resolution code side-agnostic.
enum BattleSideID: Sendable {
    case player
    case opponent
}

/// Turn-ordering / action-resolution logic for `BattleState`.
///
/// Extracted into its own file to keep `BattleState.swift` well under
/// the 500-line SwiftLint cap.
enum TurnResolution {

    private enum Constants {
        static let switchPriority: Int = 6
        static let itemPriority: Int = 6
        static let runPriority: Int = 6
        static let wildRunSuccessChance: Double = 0.5
        static let poisonBurnFractionFallback: Double = 1.0 / 16.0
    }

    /// Resolve a single turn: both sides' actions, residual status, and
    /// post-turn faint / outcome checks.
    static func resolve(
        state: inout BattleState,
        playerAction: BattleAction,
        opponentAction: BattleAction
    ) {
        // 1. Run phase (only player can run).
        if case .run = playerAction {
            let succeeded = attemptRun(state: &state)
            if succeeded {
                state.setOutcome(.fled)
                return
            }
            // Run failed: opponent still gets to act (if it's attacking).
            resolveOpponentOnlyFight(state: &state, opponentAction: opponentAction)
            endOfTurn(state: &state)
            return
        }

        // 2. Items & switches resolve before fights.
        let entries = orderedEntries(
            state: state,
            playerAction: playerAction,
            opponentAction: opponentAction
        )
        for entry in entries {
            guard state.outcome == .ongoing else { return }
            perform(entry: entry, state: &state)
            if state.outcome != .ongoing { return }
        }

        endOfTurn(state: &state)
    }

    // MARK: - Action entry

    /// A single side's action along with its computed priority/speed,
    /// used to sort fights after items/switches.
    private struct Entry {
        let side: BattleSideID
        let action: BattleAction
        let priority: Int
        let speed: Int
        let tiebreak: Int
    }

    private static func orderedEntries(
        state: BattleState,
        playerAction: BattleAction,
        opponentAction: BattleAction
    ) -> [Entry] {
        let playerEntry = makeEntry(side: .player, action: playerAction, state: state)
        let opponentEntry = makeEntry(side: .opponent, action: opponentAction, state: state)

        // Player wins exact ties deterministically (tiebreak=1 vs 0). This
        // keeps ordering stable without burning entropy from the battle RNG.
        let base = [playerEntry.withTiebreak(1), opponentEntry.withTiebreak(0)]

        return base.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            if lhs.speed != rhs.speed { return lhs.speed > rhs.speed }
            return lhs.tiebreak > rhs.tiebreak
        }
    }

    private static func makeEntry(side: BattleSideID, action: BattleAction, state: BattleState) -> Entry {
        let combatant = side == .player ? state.player.combatant : state.opponent.combatant
        let priority: Int
        switch action {
        case .fight(let slotIndex):
            if combatant.monster.moves.indices.contains(slotIndex),
               let move = MoveDex.byID[combatant.monster.moves[slotIndex].moveID] {
                priority = move.priority
            } else {
                priority = 0
            }
        case .useItem:    priority = Constants.itemPriority
        case .switchMonster: priority = Constants.switchPriority
        case .run:        priority = Constants.runPriority
        }
        return Entry(
            side: side,
            action: action,
            priority: priority,
            speed: combatant.effectiveStat(.speed),
            tiebreak: 0
        )
    }

    // MARK: - Perform a single action

    private static func perform(entry: Entry, state: inout BattleState) {
        switch entry.action {
        case .fight(let slotIndex):
            performFight(state: &state, attacker: entry.side, slotIndex: slotIndex)
        case .useItem(let itemID, let targetPartyIndex):
            performItem(state: &state, user: entry.side, itemID: itemID, targetPartyIndex: targetPartyIndex)
        case .switchMonster(let partyIndex):
            performSwitch(state: &state, side: entry.side, partyIndex: partyIndex)
        case .run:
            // Opponents can't run; player run is handled up-front.
            break
        }
    }

    // MARK: - Switching

    static func performSwitch(state: inout BattleState, side: BattleSideID, partyIndex: Int) {
        switch side {
        case .player:
            guard state.player.party.indices.contains(partyIndex) else { return }
            guard !state.player.party[partyIndex].isFainted else { return }
            state.player.syncCombatantToParty()
            state.player.activeIndex = partyIndex
            let monster = state.player.party[partyIndex]
            let species = CreatureDex.species(monster.speciesID)
            state.player.combatant = Combatant(monster: monster, species: species, isWild: false)
            state.appendEvent(.message("Go, \(state.player.combatant.displayName)!"))
        case .opponent:
            guard state.opponent.party.indices.contains(partyIndex) else { return }
            guard !state.opponent.party[partyIndex].isFainted else { return }
            state.opponent.syncCombatantToParty()
            state.opponent.activeIndex = partyIndex
            let monster = state.opponent.party[partyIndex]
            let species = CreatureDex.species(monster.speciesID)
            let isWild = state.mode == .wild
            state.opponent.combatant = Combatant(monster: monster, species: species, isWild: isWild)
            state.appendEvent(.message("Opponent sent out \(state.opponent.combatant.displayName)!"))
        }
    }

    // MARK: - Items

    private static func performItem(
        state: inout BattleState,
        user: BattleSideID,
        itemID: String,
        targetPartyIndex: Int?
    ) {
        guard let item = ItemDex.byID[itemID] else {
            state.appendEvent(.message("No such item."))
            return
        }
        ItemResolution.apply(item: item, user: user, targetPartyIndex: targetPartyIndex, state: &state)
    }

    // MARK: - Fighting

    private static func performFight(state: inout BattleState, attacker: BattleSideID, slotIndex: Int) {
        FightResolution.perform(state: &state, attacker: attacker, slotIndex: slotIndex)
    }

    private static func resolveOpponentOnlyFight(state: inout BattleState, opponentAction: BattleAction) {
        if case .fight(let slot) = opponentAction {
            performFight(state: &state, attacker: .opponent, slotIndex: slot)
        }
    }

    // MARK: - Run phase

    private static func attemptRun(state: inout BattleState) -> Bool {
        let succeeded: Bool
        switch state.mode {
        case .wild:
            var roll = 0
            state.withRNG { rng in
                roll = randomInt(below: 1_000_000, using: &rng)
            }
            succeeded = Double(roll) / 1_000_000.0 < Constants.wildRunSuccessChance
        case .trainer:
            succeeded = false
        }
        state.appendEvent(.ran(successful: succeeded))
        return succeeded
    }

    // MARK: - End-of-turn

    private static func endOfTurn(state: inout BattleState) {
        applyResidualStatus(state: &state, sideID: .player)
        if state.outcome != .ongoing { return }
        applyResidualStatus(state: &state, sideID: .opponent)
        if state.outcome != .ongoing { return }

        evaluateFaints(state: &state)
    }

    private static func applyResidualStatus(state: inout BattleState, sideID: BattleSideID) {
        var combatant = sideID == .player ? state.player.combatant : state.opponent.combatant
        guard !combatant.isFainted else { return }

        let status = combatant.monster.status
        let frac = status.damageFraction
        guard frac > 0 else { return }
        let amount = max(1, Int(Double(combatant.maxHP) * frac))
        let newHP = max(0, combatant.monster.currentHP - amount)
        let lost = combatant.monster.currentHP - newHP
        combatant.monster.currentHP = newHP
        state.appendEvent(.statusDamage(monsterID: combatant.monster.id, status: status, amount: lost))
        if combatant.isFainted {
            state.appendEvent(.fainted(monsterID: combatant.monster.id))
        }
        switch sideID {
        case .player:   state.player.combatant = combatant
        case .opponent: state.opponent.combatant = combatant
        }
    }

    private static func evaluateFaints(state: inout BattleState) {
        // Opponent fainted first (if player KO'd it this turn).
        if state.opponent.combatant.isFainted {
            awardExperience(state: &state)
            state.opponent.syncCombatantToParty()
            if let nextAlive = state.opponent.party.firstIndex(where: { !$0.isFainted }) {
                if state.mode == .wild {
                    state.setOutcome(.playerWon)
                    return
                }
                performSwitch(state: &state, side: .opponent, partyIndex: nextAlive)
            } else {
                state.setOutcome(.playerWon)
                return
            }
        }
        if state.player.combatant.isFainted {
            state.player.syncCombatantToParty()
            if state.player.party.contains(where: { !$0.isFainted }) {
                state.setAwaitingPlayerSwitch(true)
            } else {
                state.setOutcome(.playerLost)
                return
            }
        }
    }

    // MARK: - XP / level / evolve

    private static func awardExperience(state: inout BattleState) {
        let defeated = state.opponent.combatant
        let base = defeated.species.baseExperienceYield
        let level = max(1, defeated.monster.level)
        let xp = max(1, (base * level) / 7)
        guard !state.player.combatant.isFainted else { return }

        state.player.combatant.monster.experience += xp
        let monsterID = state.player.combatant.monster.id
        state.appendEvent(.experienceGained(monsterID: monsterID, amount: xp))

        levelUpLoop(state: &state)
    }

    private static func levelUpLoop(state: inout BattleState) {
        var species = state.player.combatant.species
        while true {
            let monster = state.player.combatant.monster
            let newLevel = species.growthRate.levelFromExperience(monster.experience)
            if newLevel <= monster.level { break }

            let oldHP = state.player.combatant.monster.currentHP
            let oldMax = state.player.combatant.maxHP
            state.player.combatant.monster.level = monster.level + 1
            // Preserve absolute HP increment on level-up (classic behaviour).
            let newMax = state.player.combatant.maxHP
            let gain = max(0, newMax - oldMax)
            state.player.combatant.monster.currentHP = min(newMax, oldHP + gain)

            state.appendEvent(.leveledUp(
                monsterID: state.player.combatant.monster.id,
                newLevel: state.player.combatant.monster.level
            ))

            teachLevelUpMoves(state: &state, at: state.player.combatant.monster.level)
            if let evo = species.evolution,
               state.player.combatant.monster.level >= evo.atLevel {
                performEvolution(state: &state, into: evo.intoSpeciesID)
                species = state.player.combatant.species
            }
        }
    }

    private static func teachLevelUpMoves(state: inout BattleState, at level: Int) {
        let species = state.player.combatant.species
        let newMoves = species.learnset.filter { $0.level == level }
        for entry in newMoves {
            let alreadyKnows = state.player.combatant.monster.moves.contains { $0.moveID == entry.moveID }
            if alreadyKnows { continue }
            guard let move = MoveDex.byID[entry.moveID] else { continue }
            if state.player.combatant.monster.moves.count < 4 {
                state.player.combatant.monster.moves.append(MoveSlot(move: move))
                state.appendEvent(.learnedMove(
                    monsterID: state.player.combatant.monster.id,
                    moveID: entry.moveID
                ))
            } else {
                state.appendEvent(.message("\(state.player.combatant.displayName) wants to learn \(move.name)."))
            }
        }
    }

    private static func performEvolution(state: inout BattleState, into speciesID: String) {
        guard let newSpecies = CreatureDex.byID[speciesID] else { return }
        let oldID = state.player.combatant.species.id
        let monsterID = state.player.combatant.monster.id

        // Preserve HP percentage across evolution.
        let hpFraction = Double(state.player.combatant.monster.currentHP)
            / Double(max(1, state.player.combatant.maxHP))

        state.player.combatant.monster.speciesID = newSpecies.id
        let rebuilt = Combatant(
            monster: state.player.combatant.monster,
            species: newSpecies,
            isWild: state.player.combatant.isWild
        )
        state.player.combatant = rebuilt
        let newMax = state.player.combatant.maxHP
        state.player.combatant.monster.currentHP = max(1, Int(Double(newMax) * hpFraction))

        state.appendEvent(.evolved(fromSpeciesID: oldID, toSpeciesID: newSpecies.id, monsterID: monsterID))
    }
}

private extension TurnResolution.Entry {
    func withTiebreak(_ value: Int) -> TurnResolution.Entry {
        TurnResolution.Entry(
            side: side,
            action: action,
            priority: priority,
            speed: speed,
            tiebreak: value
        )
    }
}
