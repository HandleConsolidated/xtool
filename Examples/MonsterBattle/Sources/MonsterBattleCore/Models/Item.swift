import Foundation

/// Broad category used by the bag UI.
public enum ItemCategory: String, Codable, Sendable, Hashable {
    case heal, orb, battle, keyItem
}

/// What an item does when used. One item maps to exactly one effect.
public enum ItemEffect: Codable, Sendable, Hashable {
    /// Restore a flat amount of HP (e.g. Potion).
    case heal(amount: Int)
    /// Restore all HP and cure any status (Full Restore).
    case healFull
    /// Cure a specific status. Pass `nil` to cure any non-`.none` status.
    case curStatus(StatusCondition?)
    /// Revive a fainted monster to `fraction` of its max HP.
    case revive(fraction: Double)
    /// Capture orb: multiplier applied to the base catch-rate calculation.
    case captureBall(modifier: Double)
}

/// A usable / carriable item.
public struct Item: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var emoji: String
    public var category: ItemCategory
    public var effect: ItemEffect

    public init(
        id: String,
        name: String,
        description: String,
        emoji: String,
        category: ItemCategory,
        effect: ItemEffect
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.emoji = emoji
        self.category = category
        self.effect = effect
    }
}
