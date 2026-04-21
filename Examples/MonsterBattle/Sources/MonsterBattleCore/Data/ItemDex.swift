import Foundation

/// Canonical catalogue of every Item the game knows about.
public enum ItemDex {

    // MARK: - Healing items

    private static let potion = Item(
        id: "potion",
        name: "Potion",
        description: "Restores 20 HP to a single monster.",
        emoji: "\u{1F9EA}",
        category: .heal,
        effect: .heal(amount: 20)
    )

    private static let superPotion = Item(
        id: "superPotion",
        name: "Super Potion",
        description: "Restores 50 HP to a single monster.",
        emoji: "\u{1F9EA}",
        category: .heal,
        effect: .heal(amount: 50)
    )

    private static let hyperPotion = Item(
        id: "hyperPotion",
        name: "Hyper Potion",
        description: "Restores 120 HP to a single monster.",
        emoji: "\u{1F9EA}",
        category: .heal,
        effect: .heal(amount: 120)
    )

    private static let fullRestore = Item(
        id: "fullRestore",
        name: "Full Restore",
        description: "Fully restores HP and cures any status ailment.",
        emoji: "\u{1F48A}",
        category: .heal,
        effect: .healFull
    )

    private static let revive = Item(
        id: "revive",
        name: "Revive",
        description: "Revives a fainted monster with half its HP.",
        emoji: "\u{1F494}",
        category: .heal,
        effect: .revive(fraction: 0.5)
    )

    // MARK: - Status cures

    private static let antidote = Item(
        id: "antidote",
        name: "Antidote",
        description: "Cures poison.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(.poison)
    )

    private static let burnHeal = Item(
        id: "burnHeal",
        name: "Burn Heal",
        description: "Cures a burn.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(.burn)
    )

    private static let paralyzeHeal = Item(
        id: "paralyzeHeal",
        name: "Paralyze Heal",
        description: "Cures paralysis.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(.paralyze)
    )

    private static let awakening = Item(
        id: "awakening",
        name: "Awakening",
        description: "Wakes a sleeping monster.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(.sleep)
    )

    private static let iceHeal = Item(
        id: "iceHeal",
        name: "Ice Heal",
        description: "Thaws a frozen monster.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(.freeze)
    )

    private static let fullHeal = Item(
        id: "fullHeal",
        name: "Full Heal",
        description: "Cures any status ailment.",
        emoji: "\u{1F489}",
        category: .heal,
        effect: .curStatus(nil)
    )

    // MARK: - Capture orbs

    private static let monsterOrb = Item(
        id: "monsterOrb",
        name: "Monster Orb",
        description: "A standard capture orb.",
        emoji: "\u{1F534}",
        category: .orb,
        effect: .captureBall(modifier: 1.0)
    )

    private static let greatOrb = Item(
        id: "greatOrb",
        name: "Great Orb",
        description: "A better capture orb with 1.5x catch rate.",
        emoji: "\u{1F535}",
        category: .orb,
        effect: .captureBall(modifier: 1.5)
    )

    private static let ultraOrb = Item(
        id: "ultraOrb",
        name: "Ultra Orb",
        description: "A premium capture orb with 2.0x catch rate.",
        emoji: "\u{1F7E1}",
        category: .orb,
        effect: .captureBall(modifier: 2.0)
    )

    // MARK: - Registry

    public static let all: [Item] = [
        potion, superPotion, hyperPotion, fullRestore, revive,
        antidote, burnHeal, paralyzeHeal, awakening, iceHeal, fullHeal,
        monsterOrb, greatOrb, ultraOrb
    ]

    public static let byID: [String: Item] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    public static func item(_ id: String) -> Item {
        guard let item = byID[id] else {
            preconditionFailure("Unknown item id: \(id)")
        }
        return item
    }
}
