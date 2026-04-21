import Foundation

/// The trainer's active fighting team — at most `Party.capacity` monsters.
/// Slot 0 is the lead. The `lead` computed property returns the first
/// non-fainted member, falling back to slot 0 when everyone has fainted.
public struct Party: Codable, Sendable {
    /// Maximum number of monsters in the active party.
    public static let capacity = 6

    /// Current party members, in slot order. Callers mutate through the
    /// public helpers to preserve the capacity invariant.
    public private(set) var monsters: [MonsterInstance]

    public init(monsters: [MonsterInstance] = []) {
        self.monsters = Array(monsters.prefix(Self.capacity))
    }

    /// Number of monsters currently in the party.
    public var count: Int { monsters.count }

    /// True when there are no monsters in the party.
    public var isEmpty: Bool { monsters.isEmpty }

    /// The monster that will enter battle next: the first non-fainted
    /// member, or `monsters.first` if the whole party has been downed.
    public var lead: MonsterInstance? {
        monsters.first(where: { !$0.isFainted }) ?? monsters.first
    }

    /// True iff another monster can be added without exceeding capacity.
    public var canAdd: Bool { monsters.count < Self.capacity }

    /// True when every party member has fainted — triggers a "whiteout".
    /// Returns `false` for an empty party (there is nothing to wipe out).
    public var isWipedOut: Bool {
        !monsters.isEmpty && monsters.allSatisfy({ $0.isFainted })
    }

    /// Append a monster. Returns true on success, false if the party is
    /// already at `capacity`.
    @discardableResult
    public mutating func add(_ monster: MonsterInstance) -> Bool {
        guard canAdd else { return false }
        monsters.append(monster)
        return true
    }

    /// Remove and return the monster with the given identity, if present.
    @discardableResult
    public mutating func remove(id: UUID) -> MonsterInstance? {
        guard let index = monsters.firstIndex(where: { $0.id == id }) else { return nil }
        return monsters.remove(at: index)
    }

    /// Swap the monsters at two indices. Out-of-bounds indices are silently
    /// ignored so UI drag-drop code doesn't need to guard every call.
    public mutating func swap(_ a: Int, _ b: Int) {
        guard monsters.indices.contains(a), monsters.indices.contains(b), a != b else { return }
        monsters.swapAt(a, b)
    }

    /// Replace the monster at `index`. No-op when the index is out of range.
    public mutating func replace(at index: Int, with monster: MonsterInstance) {
        guard monsters.indices.contains(index) else { return }
        monsters[index] = monster
    }

    /// Direct slot access. The setter guards against out-of-range writes.
    public subscript(index: Int) -> MonsterInstance {
        get { monsters[index] }
        set {
            guard monsters.indices.contains(index) else { return }
            monsters[index] = newValue
        }
    }

    /// Index of the first non-fainted monster, or `nil` when the whole
    /// party is downed.
    public func firstNonFaintedIndex() -> Int? {
        monsters.firstIndex(where: { !$0.isFainted })
    }

    /// Heal everyone to full HP, refill PP, and clear status conditions.
    /// HP is recomputed from the species definition; this makes the call
    /// resilient to dex edits between saves.
    public mutating func healAll() {
        for index in monsters.indices {
            monsters[index] = fullyHealed(monsters[index])
        }
    }
}

// MARK: - Internal helpers

/// Full heal at a recovery spot: HP and PP refilled, status cleared.
/// Shared between `Party`, `MonsterStorage`, and `Trainer.healAllMonsters`.
func fullyHealed(_ monster: MonsterInstance) -> MonsterInstance {
    var copy = monster
    let species = CreatureDex.species(copy.speciesID)
    copy.currentHP = copy.maxHP(using: species)
    copy.status = .none
    copy.moves = copy.moves.map { slot in
        MoveSlot(moveID: slot.moveID, currentPP: slot.maxPP, maxPP: slot.maxPP)
    }
    return copy
}
