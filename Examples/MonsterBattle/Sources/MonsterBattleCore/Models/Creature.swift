import Foundation

/// Experience growth curve used to derive level from total XP.
public enum GrowthRate: String, Codable, Sendable, Hashable, CaseIterable {
    case fast, mediumFast, mediumSlow, slow

    /// Total experience needed to be AT the given level (level 1 => 0).
    /// Simplified formulas; clamped to non-negative.
    public func experienceToReach(level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = Double(level)
        let raw: Double
        switch self {
        case .fast:
            raw = 0.8 * pow(n, 3)
        case .mediumFast:
            raw = pow(n, 3)
        case .mediumSlow:
            raw = 1.2 * pow(n, 3) - 15 * pow(n, 2) + 100 * n - 140
        case .slow:
            raw = 1.25 * pow(n, 3)
        }
        return max(0, Int(raw))
    }

    /// Given accumulated experience, return the highest level the monster
    /// has reached. Guaranteed to be >= 1.
    public func levelFromExperience(_ xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        // Most curves stop making sense past level 100 anyway.
        var level = 1
        for candidate in 2...100 where experienceToReach(level: candidate) <= xp {
            level = candidate
        }
        return level
    }
}

/// A move a creature learns at a given level during the learnset.
public struct LevelMove: Codable, Sendable, Hashable {
    public var level: Int
    public var moveID: String

    public init(level: Int, moveID: String) {
        self.level = level
        self.moveID = moveID
    }
}

/// Evolution trigger. Only "at this level" is supported for now.
public struct Evolution: Codable, Sendable, Hashable {
    public var intoSpeciesID: String
    public var atLevel: Int

    public init(intoSpeciesID: String, atLevel: Int) {
        self.intoSpeciesID = intoSpeciesID
        self.atLevel = atLevel
    }
}

/// Definition of a creature species (the "dex entry"). Runtime instances
/// live in `MonsterInstance`.
public struct CreatureSpecies: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var dexNumber: Int
    public var primaryType: Element
    public var secondaryType: Element?
    public var baseStats: Stats
    public var emoji: String
    public var description: String
    /// 0...255, higher = easier to catch.
    public var captureRate: Int
    /// ~50...250, exp given to the victor when this creature faints.
    public var baseExperienceYield: Int
    public var growthRate: GrowthRate
    public var learnset: [LevelMove]
    public var evolution: Evolution?

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        id: String,
        name: String,
        dexNumber: Int,
        primaryType: Element,
        secondaryType: Element? = nil,
        baseStats: Stats,
        emoji: String,
        description: String,
        captureRate: Int,
        baseExperienceYield: Int,
        growthRate: GrowthRate = .mediumFast,
        learnset: [LevelMove],
        evolution: Evolution? = nil
    ) {
        self.id = id
        self.name = name
        self.dexNumber = dexNumber
        self.primaryType = primaryType
        self.secondaryType = secondaryType
        self.baseStats = baseStats
        self.emoji = emoji
        self.description = description
        self.captureRate = captureRate
        self.baseExperienceYield = baseExperienceYield
        self.growthRate = growthRate
        self.learnset = learnset
        self.evolution = evolution
    }

    /// All types this species possesses (1 or 2).
    public var types: [Element] {
        if let secondaryType { return [primaryType, secondaryType] }
        return [primaryType]
    }
}
