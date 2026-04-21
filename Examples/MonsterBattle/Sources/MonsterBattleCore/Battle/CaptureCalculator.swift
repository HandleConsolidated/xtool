import Foundation

/// Resolves capture-orb throws. Uses a simplified classic formula.
public enum CaptureCalculator {

    private enum Constants {
        static let shakeCount: Int = 4
        static let aMax: Int = 255
        static let sleepFreezeBonus: Double = 2.0
        static let minorStatusBonus: Double = 1.5
    }

    /// Attempt a capture. Returns whether the orb caught the target plus
    /// the number of shakes (0...4) the UI should animate.
    ///
    /// Precondition: `item.effect` must be `.captureBall(modifier:)`.
    public static func attempt(
        on defender: Combatant,
        using item: Item,
        rng: inout any RandomNumberGenerator
    ) -> (caught: Bool, shakes: Int) {
        guard case .captureBall(let ballModifier) = item.effect else {
            // Non-ball item: treat as a guaranteed failure with 0 shakes.
            return (false, 0)
        }

        let maxHP = max(1, defender.maxHP)
        let currentHP = max(0, min(defender.monster.currentHP, maxHP))
        let captureRate = max(1, defender.species.captureRate)

        // a = ((3*maxHP - 2*currentHP) * captureRate * ballModifier) / (3*maxHP)
        let numerator = Double((3 * maxHP) - (2 * currentHP))
            * Double(captureRate)
            * max(0, ballModifier)
        let denominator = Double(3 * maxHP)
        var aValue = numerator / denominator

        // Status bonus.
        switch defender.monster.status {
        case .sleep, .freeze:
            aValue *= Constants.sleepFreezeBonus
        case .poison, .burn, .paralyze:
            aValue *= Constants.minorStatusBonus
        case .none:
            break
        }

        let aInt = min(Constants.aMax, max(0, Int(aValue.rounded(.down))))

        // Probability per shake = sqrt(a / 255). Run `shakeCount` independent
        // checks; all must pass to catch.
        let perShakeProbability = (Double(aInt) / Double(Constants.aMax)).squareRoot()
        var shakes = 0
        for _ in 0..<Constants.shakeCount {
            let roll = Double(randomInt(below: 1_000_000, using: &rng)) / 1_000_000.0
            if roll < perShakeProbability {
                shakes += 1
            } else {
                return (false, shakes)
            }
        }
        return (true, shakes)
    }
}
