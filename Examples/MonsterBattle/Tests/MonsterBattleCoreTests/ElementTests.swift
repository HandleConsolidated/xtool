import Testing
@testable import MonsterBattleCore

@Suite("Element effectiveness chart")
struct ElementTests {

    @Test func flameIsSuperEffectiveAgainstLeaf() {
        #expect(Element.flame.effectiveness(against: .leaf) == 2.0)
    }

    @Test func aquaIsSuperEffectiveAgainstFlame() {
        #expect(Element.aqua.effectiveness(against: .flame) == 2.0)
    }

    @Test func leafIsSuperEffectiveAgainstAqua() {
        #expect(Element.leaf.effectiveness(against: .aqua) == 2.0)
    }

    @Test func flameResistsFlame() {
        #expect(Element.flame.effectiveness(against: .flame) == 0.5)
    }

    @Test func effectivenessOnlyReturnsAllowedMultipliers() {
        // The current chart never uses a 0 multiplier — only 0.5, 1.0, or 2.0.
        let allowed: Set<Double> = [0.5, 1.0, 2.0]
        for attacker in Element.allCases {
            for defender in Element.allCases {
                let result = attacker.effectiveness(against: defender)
                #expect(
                    allowed.contains(result),
                    "unexpected multiplier \(result) for \(attacker) vs \(defender)"
                )
            }
        }
    }

    @Test func sixElementsExist() {
        #expect(Element.allCases.count == 6)
    }
}
