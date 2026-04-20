import Foundation

/// How a move deals damage, or whether it just applies an effect.
public enum MoveCategory: String, Codable, Sendable, Hashable {
    case physical, special, status
}

/// Full definition of a move the game knows about. Per-instance state
/// (remaining PP) lives on `MoveSlot`, not here.
public struct Move: Codable, Sendable, Hashable, Identifiable {
    /// Slug id, e.g. "ember".
    public var id: String
    /// Display name, e.g. "Ember".
    public var name: String
    public var element: Element
    public var category: MoveCategory
    /// Base power. Status moves use 0.
    public var power: Int
    /// 0...100. A value of 0 means the move cannot miss.
    public var accuracy: Int
    public var maxPP: Int
    /// Higher priority moves resolve first regardless of speed.
    public var priority: Int
    public var description: String
    /// Optional secondary effect rolled after damage resolves.
    public var effect: MoveEffect?

    public init(
        id: String,
        name: String,
        element: Element,
        category: MoveCategory,
        power: Int,
        accuracy: Int,
        maxPP: Int,
        priority: Int = 0,
        description: String,
        effect: MoveEffect? = nil
    ) {
        self.id = id
        self.name = name
        self.element = element
        self.category = category
        self.power = power
        self.accuracy = accuracy
        self.maxPP = maxPP
        self.priority = priority
        self.description = description
        self.effect = effect
    }
}

/// Secondary / rider effect attached to a move.
public struct MoveEffect: Codable, Sendable, Hashable {
    /// 0...100 probability that the rider triggers on a successful hit.
    public var chance: Int
    public var kind: Kind

    public init(chance: Int, kind: Kind) {
        self.chance = chance
        self.kind = kind
    }

    public enum Kind: Codable, Sendable, Hashable {
        case applyStatus(StatusCondition)
        case statChange(target: EffectTarget, change: StatChange)
        /// Heal user by this fraction of max HP.
        case heal(fraction: Double)
        /// Recoil damage to user as a fraction of damage dealt.
        case recoil(fraction: Double)
        case multiHit(min: Int, max: Int)
    }

    public enum EffectTarget: String, Codable, Sendable, Hashable {
        case user, opponent
    }
}
