import Foundation

/// Decides whether a move hits, factoring in accuracy/evasion stages.
public enum AccuracyCheck {

    private enum Constants {
        /// Percentage-ceiling for a bog-standard accurate move.
        static let maxAccuracyPercent: Int = 100
    }

    /// Roll a hit check for `move`. Returns true on a hit, false on a miss.
    ///
    /// Rules:
    /// - `move.accuracy == 0` always hits.
    /// - Otherwise we compute
    ///   `effective = move.accuracy * accuracyMult(attacker) / evasionMult(defender)`
    ///   then roll 1...100 and hit if `roll <= effective`.
    public static func hits(
        move: Move,
        attacker: Combatant,
        defender: Combatant,
        rng: inout any RandomNumberGenerator
    ) -> Bool {
        // Accuracy of 0 means "never misses".
        guard move.accuracy > 0 else { return true }

        let accuracyMult = attacker.stages.multiplier(for: .accuracy)
        let evasionMult = defender.stages.multiplier(for: .evasion)
        // Avoid division by zero; evasion multiplier from StatStage is always > 0.
        let safeEvasion = max(0.0001, evasionMult)
        let effective = Double(move.accuracy) * accuracyMult / safeEvasion

        let threshold = Int(effective.rounded(.down))
        // Accuracy stages can push moves past 100%; clamp to avoid never-miss
        // from trivial positive stages while preserving the usual mechanic.
        let cappedThreshold = min(max(1, threshold), Constants.maxAccuracyPercent)

        let roll = randomInt(in: 1...Constants.maxAccuracyPercent, using: &rng)
        return roll <= cappedThreshold
    }
}
