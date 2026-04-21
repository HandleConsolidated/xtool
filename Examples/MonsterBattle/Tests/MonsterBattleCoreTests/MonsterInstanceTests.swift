import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("MonsterInstance derived stats and factories")
struct MonsterInstanceTests {

    @Test func statsGiveHPGreaterThanBase() {
        let species = CreatureDex.species("voltkit")
        let instance = MonsterInstance(
            speciesID: "voltkit",
            level: 50,
            experience: 0,
            currentHP: 1,
            moves: [],
            ivs: Stats(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        )
        let stats = instance.stats(using: species)
        #expect(stats.hp > species.baseStats.hp)
    }

    @Test func level50IdealIVVoltkitMatchesFormula() {
        // Voltkit base: hp=40, attack=45, defense=40, specialAttack=65, specialDefense=45, speed=80
        let species = CreatureDex.species("voltkit")
        let instance = MonsterInstance(
            speciesID: "voltkit",
            level: 50,
            experience: 0,
            currentHP: 1,
            moves: [],
            ivs: Stats(hp: 31, attack: 31, defense: 31, specialAttack: 31, specialDefense: 31, speed: 31)
        )
        let stats = instance.stats(using: species)
        // HP = ((2*base + iv) * level / 100) + level + 10
        //    = ((2*40 + 31) * 50 / 100) + 50 + 10 = 55 + 60 = 115
        #expect(stats.hp == 115)
        // Other = ((2*base + iv) * level / 100) + 5
        //  attack = ((2*45 + 31) * 50 / 100) + 5 = 60 + 5 = 65
        #expect(stats.attack == 65)
        //  defense = ((2*40 + 31) * 50 / 100) + 5 = 55 + 5 = 60
        #expect(stats.defense == 60)
        //  specialAttack = ((2*65 + 31) * 50 / 100) + 5 = 80 + 5 = 85
        #expect(stats.specialAttack == 85)
        //  specialDefense = ((2*45 + 31) * 50 / 100) + 5 = 60 + 5 = 65
        #expect(stats.specialDefense == 65)
        //  speed = ((2*80 + 31) * 50 / 100) + 5 = 95 + 5 = 100
        #expect(stats.speed == 100)
    }

    @Test func wildPicksAtMostFourMovesAndNoneFromFuture() {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 12345)
        let species = CreatureDex.species("voltkit")
        let instance = MonsterInstance.wild(
            speciesID: "voltkit",
            level: 10,
            species: species,
            moves: MoveDex.all,
            rng: &rng
        )
        #expect(instance.moves.count <= 4)
        #expect(instance.moves.isEmpty == false)
        // Every selected move must correspond to a learnset entry with level <= 10.
        let validIDs: Set<String> = Set(species.learnset.filter { $0.level <= 10 }.map { $0.moveID })
        for slot in instance.moves {
            #expect(validIDs.contains(slot.moveID), "move \(slot.moveID) outside learnset level <= 10")
        }
    }

    @Test func wildAtHighLevelPicksExactlyFourMoves() {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 99)
        let species = CreatureDex.species("voltkit")
        let instance = MonsterInstance.wild(
            speciesID: "voltkit",
            level: 30,
            species: species,
            moves: MoveDex.all,
            rng: &rng
        )
        // voltkit has 7 learnset entries at or below level 30, so we should get the cap of 4.
        #expect(instance.moves.count == 4)
    }

    @Test func isFaintedIffCurrentHPIsZero() {
        var mon = MonsterInstance(
            speciesID: "voltkit",
            level: 5,
            experience: 0,
            currentHP: 10,
            moves: [],
            ivs: Stats.zero
        )
        #expect(mon.isFainted == false)
        mon.currentHP = 0
        #expect(mon.isFainted == true)
        mon.currentHP = 1
        #expect(mon.isFainted == false)
    }
}
