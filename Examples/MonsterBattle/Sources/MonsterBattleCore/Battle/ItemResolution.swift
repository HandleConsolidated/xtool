import Foundation

/// Applies an item during a turn. Split from TurnResolution to keep file
/// lengths under the 500-line lint cap.
enum ItemResolution {

    static func apply(
        item: Item,
        user: BattleSideID,
        targetPartyIndex: Int?,
        state: inout BattleState
    ) {
        switch item.effect {
        case .heal(let amount):
            applyHealAmount(state: &state, side: user, partyIndex: targetPartyIndex, amount: amount)
        case .healFull:
            applyHealFull(state: &state, side: user, partyIndex: targetPartyIndex)
        case .curStatus(let specific):
            applyCureStatus(state: &state, side: user, partyIndex: targetPartyIndex, specific: specific)
        case .revive(let fraction):
            applyRevive(state: &state, side: user, partyIndex: targetPartyIndex, fraction: fraction)
        case .captureBall:
            applyCaptureBall(state: &state, user: user, item: item)
        }
    }

    // MARK: - Heal helpers

    private static func applyHealAmount(
        state: inout BattleState,
        side: BattleSideID,
        partyIndex: Int?,
        amount: Int
    ) {
        let (partyIdx, maxHP, currentHP) = resolveHealTarget(state: state, side: side, partyIndex: partyIndex)
        guard partyIdx >= 0 else { return }
        let healed = min(amount, maxHP - currentHP)
        guard healed > 0 else { return }
        mutateParty(state: &state, side: side, index: partyIdx) { monster in
            monster.currentHP += healed
        }
        let mid = partyMonsterID(state: state, side: side, index: partyIdx)
        state.appendEvent(.healed(monsterID: mid, amount: healed))
    }

    private static func applyHealFull(state: inout BattleState, side: BattleSideID, partyIndex: Int?) {
        let (partyIdx, maxHP, currentHP) = resolveHealTarget(state: state, side: side, partyIndex: partyIndex)
        guard partyIdx >= 0 else { return }
        let healed = maxHP - currentHP
        let hadStatus = partyStatus(state: state, side: side, index: partyIdx) != .none
        mutateParty(state: &state, side: side, index: partyIdx) { monster in
            monster.currentHP = maxHP
            monster.status = .none
        }
        let mid = partyMonsterID(state: state, side: side, index: partyIdx)
        if healed > 0 {
            state.appendEvent(.healed(monsterID: mid, amount: healed))
        }
        if hadStatus {
            state.appendEvent(.statusCured(monsterID: mid, status: .none))
        }
    }

    private static func applyCureStatus(
        state: inout BattleState,
        side: BattleSideID,
        partyIndex: Int?,
        specific: StatusCondition?
    ) {
        let idx = effectivePartyIndex(state: state, side: side, partyIndex: partyIndex)
        guard idx >= 0 else { return }
        let current = partyStatus(state: state, side: side, index: idx)
        guard current != .none else { return }
        if let specific, specific != current { return }
        mutateParty(state: &state, side: side, index: idx) { monster in
            monster.status = .none
        }
        let mid = partyMonsterID(state: state, side: side, index: idx)
        state.appendEvent(.statusCured(monsterID: mid, status: current))
    }

    private static func applyRevive(
        state: inout BattleState,
        side: BattleSideID,
        partyIndex: Int?,
        fraction: Double
    ) {
        let idx = effectivePartyIndex(state: state, side: side, partyIndex: partyIndex)
        guard idx >= 0 else { return }
        let monster = partyMonster(state: state, side: side, index: idx)
        guard monster.isFainted else { return }
        let species = CreatureDex.species(monster.speciesID)
        let maxHP = monster.maxHP(using: species)
        let revived = max(1, Int(Double(maxHP) * max(0.01, fraction)))
        mutateParty(state: &state, side: side, index: idx) { m in
            m.currentHP = min(maxHP, revived)
            m.status = .none
        }
        let mid = partyMonsterID(state: state, side: side, index: idx)
        state.appendEvent(.healed(monsterID: mid, amount: revived))
    }

    // MARK: - Capture orbs

    private static func applyCaptureBall(state: inout BattleState, user: BattleSideID, item: Item) {
        // Capture only works from the player side against a wild opponent.
        guard user == .player, state.mode == .wild else {
            state.appendEvent(.message("Can't use \(item.name) here."))
            return
        }
        var result: (caught: Bool, shakes: Int) = (false, 0)
        state.withRNG { rng in
            result = CaptureCalculator.attempt(
                on: state.opponent.combatant,
                using: item,
                rng: &rng
            )
        }
        if result.caught {
            state.appendEvent(.caughtCreature(speciesID: state.opponent.combatant.species.id))
            state.setOutcome(.caught)
        } else {
            state.appendEvent(.captureFailed(shakes: result.shakes))
        }
    }

    // MARK: - Party index helpers

    /// Returns (partyIndex, maxHP, currentHP) for a heal target. Returns
    /// (-1, 0, 0) if no suitable target.
    private static func resolveHealTarget(
        state: BattleState,
        side: BattleSideID,
        partyIndex: Int?
    ) -> (Int, Int, Int) {
        let idx = effectivePartyIndex(state: state, side: side, partyIndex: partyIndex)
        guard idx >= 0 else { return (-1, 0, 0) }
        let monster = partyMonster(state: state, side: side, index: idx)
        if monster.isFainted { return (-1, 0, 0) }
        let species = CreatureDex.species(monster.speciesID)
        let maxHP = monster.maxHP(using: species)
        return (idx, maxHP, monster.currentHP)
    }

    private static func effectivePartyIndex(
        state: BattleState,
        side: BattleSideID,
        partyIndex: Int?
    ) -> Int {
        let party = partyFor(state: state, side: side)
        if let explicit = partyIndex, party.indices.contains(explicit) {
            return explicit
        }
        // Default to the active index.
        switch side {
        case .player:   return state.player.activeIndex
        case .opponent: return state.opponent.activeIndex
        }
    }

    private static func partyFor(state: BattleState, side: BattleSideID) -> [MonsterInstance] {
        switch side {
        case .player:   return state.player.party
        case .opponent: return state.opponent.party
        }
    }

    private static func partyMonster(state: BattleState, side: BattleSideID, index: Int) -> MonsterInstance {
        partyFor(state: state, side: side)[index]
    }

    private static func partyStatus(state: BattleState, side: BattleSideID, index: Int) -> StatusCondition {
        partyMonster(state: state, side: side, index: index).status
    }

    private static func partyMonsterID(state: BattleState, side: BattleSideID, index: Int) -> UUID {
        partyMonster(state: state, side: side, index: index).id
    }

    private static func mutateParty(
        state: inout BattleState,
        side: BattleSideID,
        index: Int,
        body: (inout MonsterInstance) -> Void
    ) {
        switch side {
        case .player:
            var monster = state.player.party[index]
            body(&monster)
            state.player.party[index] = monster
            if state.player.activeIndex == index {
                // Rebuild combatant to keep it in sync (species stays the same
                // outside of evolution, which is handled elsewhere).
                var combatant = state.player.combatant
                combatant.monster = monster
                state.player.combatant = combatant
            }
        case .opponent:
            var monster = state.opponent.party[index]
            body(&monster)
            state.opponent.party[index] = monster
            if state.opponent.activeIndex == index {
                var combatant = state.opponent.combatant
                combatant.monster = monster
                state.opponent.combatant = combatant
            }
        }
    }
}
