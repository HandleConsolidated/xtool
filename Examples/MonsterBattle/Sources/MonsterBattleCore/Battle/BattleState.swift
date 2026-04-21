import Foundation

/// Whether the opponent is a wild encounter or a named trainer.
public enum BattleMode: Sendable, Equatable {
    case wild
    case trainer(name: String)
}

/// One side of a battle (player or opponent). Keeps the party plus a
/// cached `Combatant` mirror of the active slot so combat math doesn't
/// rebuild it on every read.
public struct BattleSide: Sendable {
    /// Full party. Index 0 is the lead unless the caller switches.
    public var party: [MonsterInstance]
    /// Index of the currently-active monster within `party`.
    public var activeIndex: Int
    /// Live battle mirror of `party[activeIndex]`.
    public var combatant: Combatant

    public init(party: [MonsterInstance], activeIndex: Int, combatant: Combatant) {
        self.party = party
        self.activeIndex = activeIndex
        self.combatant = combatant
    }

    /// Convenience: build a side from a party array.
    public static func make(party: [MonsterInstance], activeIndex: Int = 0, isWild: Bool) -> BattleSide {
        precondition(!party.isEmpty, "party must contain at least one monster")
        let clampedIndex = max(0, min(activeIndex, party.count - 1))
        let monster = party[clampedIndex]
        let species = CreatureDex.species(monster.speciesID)
        let combatant = Combatant(monster: monster, species: species, isWild: isWild)
        return BattleSide(party: party, activeIndex: clampedIndex, combatant: combatant)
    }

    /// Write the combatant's mutable monster back into the party array.
    public mutating func syncCombatantToParty() {
        guard party.indices.contains(activeIndex) else { return }
        party[activeIndex] = combatant.monster
    }

    /// Does this side still have any non-fainted monsters?
    public var hasAnyAlive: Bool {
        party.contains(where: { !$0.isFainted })
    }
}

/// Value-type battle state. Deterministic for a given seed: calling
/// `submit(playerAction:)` produces the same events every time.
public struct BattleState: Sendable {
    public private(set) var turn: Int
    public private(set) var outcome: BattleOutcome
    public var player: BattleSide
    public var opponent: BattleSide
    public let mode: BattleMode
    public private(set) var log: [BattleEvent]
    public private(set) var rng: SeededRandomNumberGenerator

    /// Set when the player's active monster faints and the UI needs to
    /// prompt for a replacement. Cleared after a successful switch.
    public private(set) var awaitingPlayerSwitch: Bool = false

    public init(player: BattleSide, opponent: BattleSide, mode: BattleMode, seed: UInt64) {
        self.turn = 0
        self.outcome = .ongoing
        self.player = player
        self.opponent = opponent
        self.mode = mode
        self.log = []
        self.rng = SeededRandomNumberGenerator(seed: seed)
    }

    /// Sugar: look up the species for an arbitrary monster instance.
    public func species(for monster: MonsterInstance) -> CreatureSpecies {
        CreatureDex.species(monster.speciesID)
    }

    /// Advance the battle by one full turn. The opponent's action is
    /// decided internally via `BattleAI`.
    ///
    /// If the battle is already over, returns `[]` and does nothing.
    @discardableResult
    public mutating func submit(playerAction: BattleAction) -> [BattleEvent] {
        guard outcome == .ongoing else { return [] }

        // Handle mandatory-switch: player MUST pick a switch or items.
        if awaitingPlayerSwitch {
            let events = resolveForcedSwitch(playerAction: playerAction)
            return events
        }

        let startIndex = log.count
        turn += 1
        log.append(.turnStart(number: turn))

        // Opponent picks its action *after* the player has committed.
        var rngExistential: any RandomNumberGenerator = rng
        let opponentAction = BattleAI.chooseAction(
            for: opponent.combatant,
            against: player.combatant,
            rng: &rngExistential
        )
        if let seeded = rngExistential as? SeededRandomNumberGenerator { rng = seeded }

        // Delegate to TurnResolution for the detailed action/ordering logic.
        TurnResolution.resolve(
            state: &self,
            playerAction: playerAction,
            opponentAction: opponentAction
        )

        // Sync combatants back to party storage so callers see updated HP etc.
        player.syncCombatantToParty()
        opponent.syncCombatantToParty()

        return Array(log[startIndex...])
    }

    // MARK: - Internal hooks used by TurnResolution

    mutating func setOutcome(_ newOutcome: BattleOutcome) {
        guard outcome == .ongoing else { return }
        outcome = newOutcome
        log.append(.battleEnded(outcome: newOutcome))
    }

    mutating func setAwaitingPlayerSwitch(_ value: Bool) {
        awaitingPlayerSwitch = value
    }

    mutating func appendEvent(_ event: BattleEvent) {
        log.append(event)
    }

    mutating func withRNG<T>(_ body: (inout any RandomNumberGenerator) -> T) -> T {
        var rngExistential: any RandomNumberGenerator = rng
        let result = body(&rngExistential)
        if let seeded = rngExistential as? SeededRandomNumberGenerator {
            rng = seeded
        }
        return result
    }

    // MARK: - Forced switch handling

    private mutating func resolveForcedSwitch(playerAction: BattleAction) -> [BattleEvent] {
        let startIndex = log.count
        switch playerAction {
        case .switchMonster(let partyIndex):
            TurnResolution.performSwitch(state: &self, side: .player, partyIndex: partyIndex)
        default:
            // Auto-pick: first non-fainted party member.
            if let auto = player.party.firstIndex(where: { !$0.isFainted }) {
                TurnResolution.performSwitch(state: &self, side: .player, partyIndex: auto)
            } else {
                setOutcome(.playerLost)
            }
        }
        awaitingPlayerSwitch = false
        player.syncCombatantToParty()
        return Array(log[startIndex...])
    }
}
