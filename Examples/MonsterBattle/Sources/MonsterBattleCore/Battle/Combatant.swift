import Foundation

/// A single monster as it exists mid-battle. Wraps a `MonsterInstance`
/// with cached species data plus volatile battle state (stat stages,
/// sleep counter, flee flag).
///
/// `Combatant` is a value type: mutating it does not mutate the party
/// storage until the caller writes the updated copy back (see
/// `BattleSide.syncCombatant`).
public struct Combatant: Sendable {
    /// The mutable monster instance (HP, status, experience, etc.).
    public var monster: MonsterInstance

    /// Resolved species definition so battle math avoids repeated dex
    /// look-ups. Immutable for the lifetime of the combatant; if the
    /// monster evolves we build a fresh `Combatant`.
    public let species: CreatureSpecies

    /// In-battle stat stages. Reset on switch-out in `BattleState`.
    public var stages: StatStages

    /// Turns of sleep remaining before the monster can act again.
    /// Only meaningful when `monster.status == .sleep`.
    public var sleepTurnsRemaining: Int = 0

    /// True for wild encounters; false for trainer-owned monsters.
    public let isWild: Bool

    /// True once a wild monster has successfully fled.
    public var hasFled: Bool = false

    public init(monster: MonsterInstance, species: CreatureSpecies, isWild: Bool) {
        precondition(monster.speciesID == species.id, "species mismatch")
        self.monster = monster
        self.species = species
        self.stages = StatStages()
        self.isWild = isWild
    }

    /// Convenience: max HP from species + level + IVs.
    public var maxHP: Int { monster.maxHP(using: species) }

    /// True when `currentHP == 0`.
    public var isFainted: Bool { monster.isFainted }

    /// Convenience for logging / UI.
    public var displayName: String { monster.displayName(using: species) }

    /// Effective in-battle stat for `kind`, applying:
    /// - base stat derivation (level + IVs)
    /// - stage multiplier
    /// - status modifiers (burn halves attack, paralyze halves speed)
    ///
    /// HP is not stage-modifiable; passing `.attack` etc. here returns
    /// a minimum of 1 so downstream math never divides by zero.
    public func effectiveStat(_ kind: StatKind) -> Int {
        let baseStats = monster.stats(using: species)
        let rawStat: Int
        switch kind {
        case .attack:         rawStat = baseStats.attack
        case .defense:        rawStat = baseStats.defense
        case .specialAttack:  rawStat = baseStats.specialAttack
        case .specialDefense: rawStat = baseStats.specialDefense
        case .speed:          rawStat = baseStats.speed
        case .accuracy, .evasion:
            // These only matter through stage multipliers; raw value is 100.
            rawStat = 100
        }
        let stageMult = stages.multiplier(for: kind)
        var value = Double(rawStat) * stageMult

        // Status modifiers that affect *stats* (not damage) are applied here
        // so DamageCalculator doesn't need to know about burn/paralysis.
        switch kind {
        case .attack:
            value *= monster.status.attackMultiplier
        case .speed:
            value *= monster.status.speedMultiplier
        default:
            break
        }

        return max(1, Int(value))
    }
}
