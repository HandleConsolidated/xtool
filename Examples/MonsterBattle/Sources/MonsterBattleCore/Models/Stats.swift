import Foundation

/// Base or computed stat block. All stats are non-negative in practice
/// but the type does not enforce that so arithmetic is safe.
public struct Stats: Codable, Sendable, Hashable {
    public var hp: Int
    public var attack: Int
    public var defense: Int
    public var specialAttack: Int
    public var specialDefense: Int
    public var speed: Int

    public init(
        hp: Int,
        attack: Int,
        defense: Int,
        specialAttack: Int,
        specialDefense: Int,
        speed: Int
    ) {
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.specialAttack = specialAttack
        self.specialDefense = specialDefense
        self.speed = speed
    }

    public static let zero = Stats(
        hp: 0, attack: 0, defense: 0,
        specialAttack: 0, specialDefense: 0, speed: 0
    )

    public func total() -> Int {
        hp + attack + defense + specialAttack + specialDefense + speed
    }

    public static func + (lhs: Stats, rhs: Stats) -> Stats {
        Stats(
            hp: lhs.hp + rhs.hp,
            attack: lhs.attack + rhs.attack,
            defense: lhs.defense + rhs.defense,
            specialAttack: lhs.specialAttack + rhs.specialAttack,
            specialDefense: lhs.specialDefense + rhs.specialDefense,
            speed: lhs.speed + rhs.speed
        )
    }

    public static func - (lhs: Stats, rhs: Stats) -> Stats {
        Stats(
            hp: lhs.hp - rhs.hp,
            attack: lhs.attack - rhs.attack,
            defense: lhs.defense - rhs.defense,
            specialAttack: lhs.specialAttack - rhs.specialAttack,
            specialDefense: lhs.specialDefense - rhs.specialDefense,
            speed: lhs.speed - rhs.speed
        )
    }
}

/// Which in-battle modifiable stat a `StatChange` refers to.
/// Note HP isn't stage-modifiable.
public enum StatKind: String, Codable, Sendable, CaseIterable, Hashable {
    case attack, defense, specialAttack, specialDefense, speed, accuracy, evasion
}

/// A single stage change to apply to a combatant (e.g. +2 to attack).
public struct StatChange: Codable, Sendable, Hashable {
    public var stat: StatKind
    public var delta: Int

    public init(stat: StatKind, delta: Int) {
        self.stat = stat
        self.delta = delta
    }
}

/// A single -6...+6 stage slot. Use the `multiplier` property to
/// convert it into a damage/accuracy scalar.
public struct StatStage: Codable, Sendable, Hashable {
    public var value: Int

    public init(_ value: Int = 0) {
        self.value = max(-6, min(6, value))
    }

    /// Standard formula: max(2, 2+stage) / max(2, 2-stage).
    public var multiplier: Double {
        let clamped = max(-6, min(6, value))
        let num = Double(max(2, 2 + clamped))
        let den = Double(max(2, 2 - clamped))
        return num / den
    }

    public mutating func apply(delta: Int) {
        value = max(-6, min(6, value + delta))
    }
}

/// Full bundle of in-battle stage modifiers applied to a single combatant.
public struct StatStages: Codable, Sendable, Hashable {
    public var attack: Int
    public var defense: Int
    public var specialAttack: Int
    public var specialDefense: Int
    public var speed: Int
    public var accuracy: Int
    public var evasion: Int

    public init(
        attack: Int = 0,
        defense: Int = 0,
        specialAttack: Int = 0,
        specialDefense: Int = 0,
        speed: Int = 0,
        accuracy: Int = 0,
        evasion: Int = 0
    ) {
        self.attack = attack
        self.defense = defense
        self.specialAttack = specialAttack
        self.specialDefense = specialDefense
        self.speed = speed
        self.accuracy = accuracy
        self.evasion = evasion
    }

    public mutating func apply(_ change: StatChange) {
        switch change.stat {
        case .attack:         attack = clamp(attack + change.delta)
        case .defense:        defense = clamp(defense + change.delta)
        case .specialAttack:  specialAttack = clamp(specialAttack + change.delta)
        case .specialDefense: specialDefense = clamp(specialDefense + change.delta)
        case .speed:          speed = clamp(speed + change.delta)
        case .accuracy:       accuracy = clamp(accuracy + change.delta)
        case .evasion:        evasion = clamp(evasion + change.delta)
        }
    }

    /// Returns the current stage value for the given kind.
    public func stage(for kind: StatKind) -> Int {
        switch kind {
        case .attack:         return attack
        case .defense:        return defense
        case .specialAttack:  return specialAttack
        case .specialDefense: return specialDefense
        case .speed:          return speed
        case .accuracy:       return accuracy
        case .evasion:        return evasion
        }
    }

    /// Multiplier that should be applied when computing the effective stat.
    /// Accuracy and evasion use a slightly gentler 3/(3+n) curve in some
    /// games, but for simplicity we share the standard formula.
    public func multiplier(for kind: StatKind) -> Double {
        StatStage(stage(for: kind)).multiplier
    }

    private func clamp(_ value: Int) -> Int {
        max(-6, min(6, value))
    }
}
