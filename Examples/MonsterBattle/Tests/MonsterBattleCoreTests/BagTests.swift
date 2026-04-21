import Testing
@testable import MonsterBattleCore

@Suite("Bag inventory")
struct BagTests {

    @Test func addIncrementsQuantity() {
        var bag = Bag()
        bag.add("potion", count: 2)
        #expect(bag.quantity(of: "potion") == 2)
        bag.add("potion", count: 3)
        #expect(bag.quantity(of: "potion") == 5)
    }

    @Test func removeDecrementsQuantity() {
        var bag = Bag()
        bag.add("potion", count: 5)
        let removed = bag.remove("potion", count: 2)
        #expect(removed == true)
        #expect(bag.quantity(of: "potion") == 3)
    }

    @Test func removeBelowZeroReturnsFalseAndLeavesBagUnchanged() {
        var bag = Bag()
        bag.add("potion", count: 1)
        let removed = bag.remove("potion", count: 5)
        #expect(removed == false)
        #expect(bag.quantity(of: "potion") == 1)
    }

    @Test func unknownItemIDsAreStoredButFilteredByListed() {
        var bag = Bag()
        bag.add("totally-made-up-item", count: 3)
        // The raw quantity is tracked...
        #expect(bag.quantity(of: "totally-made-up-item") == 3)
        // ... but listed() silently drops entries that ItemDex doesn't know.
        let listed = bag.listed()
        #expect(listed.allSatisfy { $0.item.id != "totally-made-up-item" })
    }

    @Test func listedCategoryFiltersByCategory() {
        var bag = Bag()
        bag.add("potion", count: 1)        // heal
        bag.add("monsterOrb", count: 1)    // orb
        bag.add("ultraOrb", count: 2)      // orb

        let healOnly = bag.listed(category: .heal)
        #expect(healOnly.count == 1)
        #expect(healOnly.first?.item.id == "potion")

        let orbOnly = bag.listed(category: .orb)
        let orbIDs = Set(orbOnly.map { $0.item.id })
        #expect(orbIDs == ["monsterOrb", "ultraOrb"])
    }

    @Test func addRejectsNonPositiveCounts() {
        var bag = Bag()
        bag.add("potion", count: 0)
        #expect(bag.quantity(of: "potion") == 0)
        bag.add("potion", count: -5)
        #expect(bag.quantity(of: "potion") == 0)
    }

    @Test func initializerFiltersZeroOrNegativeStartingEntries() {
        let bag = Bag(contents: ["potion": 3, "ghost": 0, "phantom": -1])
        #expect(bag.quantity(of: "potion") == 3)
        #expect(bag.quantity(of: "ghost") == 0)
        #expect(bag.quantity(of: "phantom") == 0)
    }
}
