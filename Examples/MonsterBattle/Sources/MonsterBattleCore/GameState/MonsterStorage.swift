import Foundation

/// Uncapped overflow box used when the active `Party` is full.
public struct MonsterStorage: Codable, Sendable {
    /// Stored monsters, in the order they were deposited.
    public private(set) var monsters: [MonsterInstance]

    public init(monsters: [MonsterInstance] = []) {
        self.monsters = monsters
    }

    /// Number of monsters currently in storage.
    public var count: Int { monsters.count }

    /// Place a monster into storage.
    public mutating func deposit(_ monster: MonsterInstance) {
        monsters.append(monster)
    }

    /// Remove and return the monster with the given identity, if present.
    @discardableResult
    public mutating func withdraw(id: UUID) -> MonsterInstance? {
        guard let index = monsters.firstIndex(where: { $0.id == id }) else { return nil }
        return monsters.remove(at: index)
    }

    /// Heal every stored monster to full HP and clear their status.
    public mutating func healAll() {
        for index in monsters.indices {
            monsters[index] = fullyHealed(monsters[index])
        }
    }
}
