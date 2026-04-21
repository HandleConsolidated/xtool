import Foundation

/// Opponent action selection. Wild encounters always Fight; trainer AI
/// (future) picks highest-damage moves with a dash of noise.
public enum BattleAI {

    private enum Constants {
        /// Probability that a trainer picks a random move instead of the
        /// projected-best one. Keeps battles from feeling mechanical.
        static let randomPickChance: Double = 0.20
    }

    /// Pick an action for the AI-controlled `combatant` facing `opponent`.
    /// Wild combatants only Fight; a trainer combatant returns the move
    /// with the highest *expected* damage (computed via the real damage
    /// formula with a neutral RNG pass).
    public static func chooseAction(
        for combatant: Combatant,
        against opponent: Combatant,
        partyIndexFallback: Int = 0,
        rng: inout any RandomNumberGenerator
    ) -> BattleAction {
        let usableSlots = combatant.monster.moves.enumerated().filter { $0.element.currentPP > 0 }

        // If everything is out of PP, fall back to Struggle-ish behaviour: pick
        // the first slot anyway; BattleState will handle the PP-zero case.
        guard let pick = usableSlots.first else {
            return .fight(moveSlotIndex: 0)
        }

        // Wild monsters always attack.
        if combatant.isWild {
            return .fight(moveSlotIndex: pick.offset)
        }

        // Trainer branch: occasional random flavour.
        let randomRoll = Double(randomInt(below: 1_000, using: &rng)) / 1_000.0
        if randomRoll < Constants.randomPickChance {
            if let random = usableSlots.randomElement(usingAny: &rng) {
                return .fight(moveSlotIndex: random.offset)
            }
        }

        // Greedy: compute expected damage for each usable move using a copy
        // of the RNG so the real battle RNG is not disturbed by scoring.
        var bestIndex = pick.offset
        var bestScore = -1
        for (offset, slot) in usableSlots {
            guard let move = MoveDex.byID[slot.moveID] else { continue }
            var scoringRNG: any RandomNumberGenerator = SeededRandomNumberGenerator(
                seed: UInt64(bitPattern: Int64(offset + 1)) &* 0x9E37_79B9_7F4A_7C15
            )
            let preview = DamageCalculator.compute(
                attacker: combatant,
                defender: opponent,
                move: move,
                rng: &scoringRNG
            )
            if preview.damage > bestScore {
                bestScore = preview.damage
                bestIndex = offset
            }
        }
        _ = partyIndexFallback // reserved for a future switch-AI branch.
        return .fight(moveSlotIndex: bestIndex)
    }
}
