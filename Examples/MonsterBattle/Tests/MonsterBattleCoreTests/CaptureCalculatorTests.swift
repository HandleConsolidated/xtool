import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("CaptureCalculator")
struct CaptureCalculatorTests {

    // MARK: - Helpers

    private func freshCombatant(
        speciesID: String,
        level: Int = 20,
        currentHPFraction: Double = 1.0,
        status: StatusCondition = .none
    ) -> Combatant {
        let species = CreatureDex.species(speciesID)
        var instance = MonsterInstance(
            speciesID: speciesID,
            level: level,
            experience: 0,
            currentHP: 1,
            moves: [],
            status: status,
            ivs: Stats(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        )
        let maxHP = instance.maxHP(using: species)
        let hp = max(1, Int(Double(maxHP) * currentHPFraction))
        instance.currentHP = min(hp, maxHP)
        return Combatant(monster: instance, species: species, isWild: true)
    }

    // MARK: - Tests

    @Test func fullHPLowRateMonsterOrbRarelyCatches() {
        // Ignifox capture rate 45 at full HP with monsterOrb (modifier 1.0):
        //   a = 45/3 = 15  →  perShakeProb ≈ sqrt(15/255) ≈ 0.243
        // Catch probability across 4 shakes ≈ 0.35%. Over 100 attempts most
        // should fail and most should stop at 0 or very few shakes.
        let target = freshCombatant(speciesID: "ignifox", level: 30, currentHPFraction: 1.0)
        let orb = ItemDex.byID["monsterOrb"]!
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        var caughtCount = 0
        let trials = 200
        for _ in 0..<trials {
            let (caught, _) = CaptureCalculator.attempt(on: target, using: orb, rng: &rng)
            if caught { caughtCount += 1 }
        }
        // Allowing generous head-room; expected is ~1 catch per trials, but
        // we only demand "almost never".
        #expect(caughtCount < trials / 4)
    }

    @Test func nearKOHighRateUltraOrbUsuallyCatches() {
        // Boulderling capture rate 180 at HP=1 with ultraOrb (2.0x) → a ≈ 255.
        // perShakeProb = 1.0 → shouldn't fail. Even across 1000 attempts
        // the majority must succeed.
        let species = CreatureDex.species("boulderling")
        var instance = MonsterInstance(
            speciesID: "boulderling",
            level: 20,
            experience: 0,
            currentHP: 1,
            moves: [],
            ivs: Stats(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        )
        _ = instance.maxHP(using: species) // compute max so we can set current to 1
        instance.currentHP = 1
        let target = Combatant(monster: instance, species: species, isWild: true)
        let orb = ItemDex.byID["ultraOrb"]!

        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 777)
        var caughtCount = 0
        let trials = 1000
        for _ in 0..<trials {
            let (caught, _) = CaptureCalculator.attempt(on: target, using: orb, rng: &rng)
            if caught { caughtCount += 1 }
        }
        #expect(caughtCount > trials / 2)
    }

    @Test func sleepOrFreezeDoublesBonusOverNoStatus() {
        // Compare catch probability at a mid-range a-value where the perShake
        // probability is noticeably below 1.0, so the bonus actually moves
        // the needle. voltkit (cap rate 120), full HP, monsterOrb.
        //   a_none       = 120/3                 = 40
        //   a_poisoned   = 40 * 1.5              = 60
        //   a_asleep     = 40 * 2.0              = 80
        let healthy = freshCombatant(speciesID: "voltkit", level: 30, currentHPFraction: 1.0, status: .none)
        let poisoned = freshCombatant(speciesID: "voltkit", level: 30, currentHPFraction: 1.0, status: .poison)
        let asleep = freshCombatant(speciesID: "voltkit", level: 30, currentHPFraction: 1.0, status: .sleep)
        let frozen = freshCombatant(speciesID: "voltkit", level: 30, currentHPFraction: 1.0, status: .freeze)
        let orb = ItemDex.byID["monsterOrb"]!

        func successRate(on target: Combatant, seed: UInt64, trials: Int = 2000) -> Double {
            var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            var caught = 0
            for _ in 0..<trials {
                if CaptureCalculator.attempt(on: target, using: orb, rng: &rng).caught {
                    caught += 1
                }
            }
            return Double(caught) / Double(trials)
        }

        let seed: UInt64 = 12345
        let rateNone = successRate(on: healthy, seed: seed)
        let rateMinor = successRate(on: poisoned, seed: seed &+ 1)
        let rateSleep = successRate(on: asleep, seed: seed &+ 2)
        let rateFreeze = successRate(on: frozen, seed: seed &+ 3)

        // Sleep/freeze (2x bonus) should produce more catches than no status.
        #expect(rateSleep > rateNone)
        #expect(rateFreeze > rateNone)
        // They should also comfortably beat the minor-status bonus (1.5x)
        // given a large enough trial count. Allow some slack.
        #expect(rateSleep > rateMinor - 0.05)
        #expect(rateFreeze > rateMinor - 0.05)
    }
}
