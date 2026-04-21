import Testing
@testable import MonsterBattleCore

@Suite("Stats arithmetic and stage math")
struct StatsTests {

    @Test func zeroIsAllZero() {
        let zero = Stats.zero
        #expect(zero.hp == 0)
        #expect(zero.attack == 0)
        #expect(zero.defense == 0)
        #expect(zero.specialAttack == 0)
        #expect(zero.specialDefense == 0)
        #expect(zero.speed == 0)
        #expect(zero.total() == 0)
    }

    @Test func additionIsComponentWise() {
        let a = Stats(hp: 1, attack: 2, defense: 3, specialAttack: 4, specialDefense: 5, speed: 6)
        let b = Stats(hp: 10, attack: 20, defense: 30, specialAttack: 40, specialDefense: 50, speed: 60)
        let c = a + b
        #expect(c.hp == 11)
        #expect(c.attack == 22)
        #expect(c.defense == 33)
        #expect(c.specialAttack == 44)
        #expect(c.specialDefense == 55)
        #expect(c.speed == 66)
    }

    @Test func subtractionIsComponentWise() {
        let a = Stats(hp: 10, attack: 20, defense: 30, specialAttack: 40, specialDefense: 50, speed: 60)
        let b = Stats(hp: 1, attack: 2, defense: 3, specialAttack: 4, specialDefense: 5, speed: 6)
        let c = a - b
        #expect(c.hp == 9)
        #expect(c.attack == 18)
        #expect(c.defense == 27)
        #expect(c.specialAttack == 36)
        #expect(c.specialDefense == 45)
        #expect(c.speed == 54)
    }

    @Test func totalSumsAllSixStats() {
        let s = Stats(hp: 1, attack: 2, defense: 3, specialAttack: 4, specialDefense: 5, speed: 6)
        #expect(s.total() == 21)
    }

    @Test func statStageZeroHasMultiplierOne() {
        #expect(StatStage(0).multiplier == 1.0)
    }

    @Test func statStagePositiveTwoIsDouble() {
        #expect(StatStage(2).multiplier == 2.0)
    }

    @Test func statStageNegativeTwoIsHalf() {
        #expect(StatStage(-2).multiplier == 0.5)
    }

    @Test func statStageClampsAtPlusSix() {
        let s = StatStage(99)
        #expect(s.value == 6)
        #expect(s.multiplier == StatStage(6).multiplier)
    }

    @Test func statStageClampsAtMinusSix() {
        let s = StatStage(-99)
        #expect(s.value == -6)
        #expect(s.multiplier == StatStage(-6).multiplier)
    }

    @Test func statStagesApplyChangeAffectsAttack() {
        var stages = StatStages()
        stages.apply(StatChange(stat: .attack, delta: 2))
        #expect(stages.attack == 2)
    }

    @Test func statStagesApplyChangeDoesNotLeakBetweenStats() {
        var stages = StatStages()
        stages.apply(StatChange(stat: .attack, delta: 2))
        #expect(stages.defense == 0)
        #expect(stages.speed == 0)
    }
}
