import Foundation

/// Result of a single damage calculation.
public struct DamageResult: Sendable {
    /// Final damage value. `0` for status moves, no-effect hits, or
    /// effectiveness == 0. Non-zero damage is always at least 1.
    public var damage: Int
    /// Product of the per-type matchup multipliers against the defender.
    public var effectiveness: Double
    /// True when the critical-hit roll succeeded.
    public var critical: Bool

    public init(damage: Int, effectiveness: Double, critical: Bool) {
        self.damage = damage
        self.effectiveness = effectiveness
        self.critical = critical
    }
}

/// Pure, deterministic damage math. All randomness comes from the
/// caller-owned `rng`, so the same seed replays identically.
public enum DamageCalculator {

    private enum Constants {
        static let stab: Double = 1.5
        static let criticalMultiplier: Double = 1.5
        static let criticalChanceDenominator: Int = 24
        // Classic 16-bucket random factor [0.85, 1.00].
        static let randomBuckets: Int = 16
        static let randomMin: Double = 0.85
        static let randomMax: Double = 1.00
    }

    /// Compute damage for a move hit. Assumes the caller has already
    /// confirmed the move landed (see `AccuracyCheck`).
    ///
    /// Note: burn's attack-halving is applied inside
    /// `Combatant.effectiveStat(.attack)`, so this function does **not**
    /// re-apply a burn modifier. Paralysis speed is handled similarly
    /// (but is only relevant for turn ordering, not damage).
    public static func compute(
        attacker: Combatant,
        defender: Combatant,
        move: Move,
        rng: inout any RandomNumberGenerator
    ) -> DamageResult {
        // Status moves deal no damage.
        guard move.category != .status else {
            return DamageResult(damage: 0, effectiveness: 1.0, critical: false)
        }

        // Type effectiveness: product over defender types.
        let defenderTypes = defender.species.types
        var effectiveness: Double = 1.0
        for t in defenderTypes {
            effectiveness *= move.element.effectiveness(against: t)
        }

        // Immune? Short-circuit.
        guard effectiveness > 0 else {
            return DamageResult(damage: 0, effectiveness: 0.0, critical: false)
        }

        // Select A / D stats per category.
        let attackStat: Int
        let defenseStat: Int
        switch move.category {
        case .physical:
            attackStat = attacker.effectiveStat(.attack)
            defenseStat = defender.effectiveStat(.defense)
        case .special:
            attackStat = attacker.effectiveStat(.specialAttack)
            defenseStat = defender.effectiveStat(.specialDefense)
        case .status:
            // Unreachable; early-return above.
            return DamageResult(damage: 0, effectiveness: effectiveness, critical: false)
        }

        let level = max(1, attacker.monster.level)
        let power = max(0, move.power)

        // Base formula: (((2*L/5 + 2) * Power * A / D) / 50) + 2
        let levelFactor = (2.0 * Double(level)) / 5.0 + 2.0
        let numerator = levelFactor * Double(power) * Double(attackStat)
        let base = (numerator / Double(max(1, defenseStat))) / 50.0 + 2.0

        // STAB: 1.5x if move type matches either attacker type.
        let isSTAB = attacker.species.types.contains(move.element)
        let stab = isSTAB ? Constants.stab : 1.0

        // Critical: 1/24 chance, 1.5x damage.
        let critRoll = randomInt(below: Constants.criticalChanceDenominator, using: &rng)
        let critical = critRoll == 0
        let critMult = critical ? Constants.criticalMultiplier : 1.0

        // Random factor: 0.85...1.00 in 16 buckets.
        let bucket = randomInt(below: Constants.randomBuckets, using: &rng)
        let spread = Constants.randomMax - Constants.randomMin
        let randomFactor = Constants.randomMin
            + spread * Double(bucket) / Double(Constants.randomBuckets - 1)

        let modifier = stab * effectiveness * critMult * randomFactor
        var damage = Int((base * modifier).rounded(.down))

        // Classic "at least 1" rule when the move actually connected.
        if damage < 1 && effectiveness > 0 && power > 0 {
            damage = 1
        }

        return DamageResult(damage: damage, effectiveness: effectiveness, critical: critical)
    }
}
