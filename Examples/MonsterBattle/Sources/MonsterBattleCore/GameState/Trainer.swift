import Foundation

/// Where a newly-acquired monster ended up after being added to the trainer.
public enum MonsterAddDestination: Sendable, Equatable {
    case party
    case storage
}

/// The persistent player profile: party, storage box, bag, money, badges,
/// and cumulative playtime. Does not hold transient UI state or RNG.
public struct Trainer: Codable, Sendable {
    /// Display name chosen during `newGame`.
    public var name: String
    /// Stable identity, used by the save system to detect "is this still
    /// the same trainer" across saves.
    public var id: UUID
    /// Player currency.
    public var money: Int
    /// Active fighting party (up to `Party.capacity`).
    public var party: Party
    /// Overflow "box" used when the party is full.
    public var storage: MonsterStorage
    /// Item inventory.
    public var bag: Bag
    /// Badge IDs earned from defeating gym-leader-style trainers.
    public var badges: Set<String>
    /// Total in-game seconds spent with a save file. Incremented via
    /// `updatePlaytime(delta:)`.
    public var playtimeSeconds: Int

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        name: String,
        id: UUID = UUID(),
        money: Int = 1000,
        party: Party = Party(),
        storage: MonsterStorage = MonsterStorage(),
        bag: Bag = Bag(),
        badges: Set<String> = [],
        playtimeSeconds: Int = 0
    ) {
        self.name = name
        self.id = id
        self.money = money
        self.party = party
        self.storage = storage
        self.bag = bag
        self.badges = badges
        self.playtimeSeconds = playtimeSeconds
    }

    /// Add a monster to the party if there's room, otherwise stash it in
    /// storage. Returns where it ended up so the caller can show the
    /// appropriate "sent to box" message.
    @discardableResult
    public mutating func addMonster(_ monster: MonsterInstance) -> MonsterAddDestination {
        if party.canAdd {
            _ = party.add(monster)
            return .party
        }
        storage.deposit(monster)
        return .storage
    }

    /// Award prize money. Negative amounts are ignored.
    public mutating func awardMoney(_ amount: Int) {
        guard amount > 0 else { return }
        money += amount
    }

    /// Attempt to spend money. Returns `false` and leaves the wallet
    /// untouched when the trainer doesn't have enough.
    @discardableResult
    public mutating func spendMoney(_ amount: Int) -> Bool {
        guard amount >= 0 else { return false }
        guard money >= amount else { return false }
        money -= amount
        return true
    }

    /// Increment the cumulative playtime by `delta` seconds. Negative
    /// deltas are ignored so clock drift can't eat into the counter.
    public mutating func updatePlaytime(delta: Int) {
        guard delta > 0 else { return }
        playtimeSeconds += delta
    }

    /// Heal the entire party AND the storage box to full. Equivalent to
    /// visiting a recovery facility; used both there and on whiteout
    /// recovery.
    public mutating func healAllMonsters() {
        party.healAll()
        storage.healAll()
    }
}
