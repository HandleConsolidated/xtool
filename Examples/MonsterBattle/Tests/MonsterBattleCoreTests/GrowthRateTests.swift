import Testing
@testable import MonsterBattleCore

@Suite("GrowthRate XP curves")
struct GrowthRateTests {

    @Test func mediumFastAtLevelOneIsZero() {
        #expect(GrowthRate.mediumFast.experienceToReach(level: 1) == 0)
    }

    @Test func mediumFastAtLevelOneHundredIsExactlyOneMillion() {
        #expect(GrowthRate.mediumFast.experienceToReach(level: 100) == 1_000_000)
    }

    // The mediumSlow formula has an early-level dip below mediumFast that
    // "crosses over" around level ~35, so the clean fast < mediumFast <
    // mediumSlow < slow ordering only holds at levels well past the
    // crossover. We check at level 100 where the canonical ordering is
    // unambiguous.
    @Test func xpAtLevelOneHundredIsOrderedByCurveShape() {
        let fast = GrowthRate.fast.experienceToReach(level: 100)
        let mediumFast = GrowthRate.mediumFast.experienceToReach(level: 100)
        let mediumSlow = GrowthRate.mediumSlow.experienceToReach(level: 100)
        let slow = GrowthRate.slow.experienceToReach(level: 100)
        #expect(fast < mediumFast)
        #expect(mediumFast < mediumSlow)
        #expect(mediumSlow < slow)
    }

    @Test func levelFromExperienceInvertsExperienceToReachForCommonLevels() {
        for curve in GrowthRate.allCases {
            for level in [2, 10, 50, 100] {
                let xp = curve.experienceToReach(level: level)
                let back = curve.levelFromExperience(xp)
                #expect(back == level, "curve \(curve) level \(level) round-trip gave \(back)")
            }
        }
    }

    @Test func levelOneFromZeroExperience() {
        for curve in GrowthRate.allCases {
            #expect(curve.levelFromExperience(0) == 1)
        }
    }
}
