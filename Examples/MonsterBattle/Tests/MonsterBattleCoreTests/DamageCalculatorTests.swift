import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("DamageCalculator")
struct DamageCalculatorTests {

    // MARK: - Helpers

    private func combatant(speciesID: String, level: Int = 50) -> Combatant {
        let species = CreatureDex.species(speciesID)
        let instance = MonsterInstance(
            speciesID: speciesID,
            level: level,
            experience: 0,
            currentHP: 1,
            moves: [],
            ivs: Stats(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        )
        var mutable = instance
        mutable.currentHP = mutable.maxHP(using: species)
        return Combatant(monster: mutable, species: species, isWild: true)
    }

    // MARK: - Tests

    @Test func statusMovesDealZeroDamage() {
        let attacker = combatant(speciesID: "flarepup")
        let defender = combatant(speciesID: "voltkit")
        let growl = MoveDex.byID["growl"]!
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let result = DamageCalculator.compute(
            attacker: attacker,
            defender: defender,
            move: growl,
            rng: &rng
        )
        #expect(result.damage == 0)
    }

    @Test func stabBeatsOffTypeOfEqualPower() {
        // Ember (flame special 40) vs zephyrix (gust): flame→gust = 1.0, STAB from flarepup.
        // Bubble (aqua special 40) vs zephyrix (gust): aqua→gust = 1.0, no STAB.
        let flarepup = combatant(speciesID: "flarepup")
        let zephyrix = combatant(speciesID: "zephyrix")
        let ember = MoveDex.byID["ember"]!
        let bubble = MoveDex.byID["bubble"]!

        var rng1: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)
        var rng2: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

        let stabResult = DamageCalculator.compute(
            attacker: flarepup,
            defender: zephyrix,
            move: ember,
            rng: &rng1
        )
        let offTypeResult = DamageCalculator.compute(
            attacker: flarepup,
            defender: zephyrix,
            move: bubble,
            rng: &rng2
        )

        #expect(stabResult.effectiveness == 1.0)
        #expect(offTypeResult.effectiveness == 1.0)
        #expect(stabResult.damage > offTypeResult.damage)
    }

    @Test func superEffectiveBeatsNeutralAgainstSameDefender() {
        // voltkit (spark) attacks tidepaw (aqua).
        //   vinewhip (leaf physical 40): leaf→aqua = 2.0, no STAB.
        //   tackle   (stone physical 40): stone→aqua = 1.0, no STAB.
        let voltkit = combatant(speciesID: "voltkit")
        let tidepaw = combatant(speciesID: "tidepaw")
        let vinewhip = MoveDex.byID["vinewhip"]!
        let tackle = MoveDex.byID["tackle"]!

        var rng1: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)
        var rng2: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 7)

        let superEff = DamageCalculator.compute(
            attacker: voltkit,
            defender: tidepaw,
            move: vinewhip,
            rng: &rng1
        )
        let neutral = DamageCalculator.compute(
            attacker: voltkit,
            defender: tidepaw,
            move: tackle,
            rng: &rng2
        )

        #expect(superEff.effectiveness == 2.0)
        #expect(neutral.effectiveness == 1.0)
        #expect(superEff.damage > neutral.damage)
    }

    @Test func damageIsAtLeastOneOnNonZeroEffectivenessHit() {
        // A level-1 attacker with minimal power shouldn't be able to roll 0.
        let attacker = combatant(speciesID: "flarepup", level: 1)
        let defender = combatant(speciesID: "boulderling", level: 100)
        let ember = MoveDex.byID["ember"]!
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 9)
        let result = DamageCalculator.compute(
            attacker: attacker,
            defender: defender,
            move: ember,
            rng: &rng
        )
        #expect(result.effectiveness > 0)
        #expect(result.damage >= 1)
    }

    @Test func dualTypeEffectivenessMultipliesTogether() {
        // Verdantor is leaf/stone. Flame: leaf=x2.0, stone=x0.5 → product = 1.0.
        let flarepup = combatant(speciesID: "flarepup")
        let verdantor = combatant(speciesID: "verdantor")
        let ember = MoveDex.byID["ember"]!

        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 3)
        let result = DamageCalculator.compute(
            attacker: flarepup,
            defender: verdantor,
            move: ember,
            rng: &rng
        )
        #expect(result.effectiveness == 1.0)
    }

    @Test func sameSeedProducesSameDamage() {
        let attacker = combatant(speciesID: "flarepup")
        let defender = combatant(speciesID: "voltkit")
        let ember = MoveDex.byID["ember"]!

        var rng1: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 12345)
        var rng2: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 12345)

        let first = DamageCalculator.compute(
            attacker: attacker,
            defender: defender,
            move: ember,
            rng: &rng1
        )
        let second = DamageCalculator.compute(
            attacker: attacker,
            defender: defender,
            move: ember,
            rng: &rng2
        )

        #expect(first.damage == second.damage)
        #expect(first.critical == second.critical)
        #expect(first.effectiveness == second.effectiveness)
    }
}
