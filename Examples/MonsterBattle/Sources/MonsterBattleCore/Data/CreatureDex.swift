import Foundation

/// The hand-authored list of all creature species in the game. All
/// entries are original content. Base-stat totals are kept within
/// roughly 300-500 for balance.
public enum CreatureDex {

    // MARK: - Flame line (Flarepup / Ignifox)

    private static let flarepup = CreatureSpecies(
        id: "flarepup",
        name: "Flarepup",
        dexNumber: 1,
        primaryType: .flame,
        baseStats: Stats(hp: 45, attack: 55, defense: 40, specialAttack: 60, specialDefense: 40, speed: 60),
        emoji: "\u{1F98A}", // fox face
        description: "A playful pup whose fur crackles with ember-sparks when excited.",
        captureRate: 45,
        baseExperienceYield: 62,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "scratch"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 5,  moveID: "ember"),
            LevelMove(level: 10, moveID: "quickjab"),
            LevelMove(level: 15, moveID: "bodyslam"),
            LevelMove(level: 20, moveID: "flameburst"),
            LevelMove(level: 25, moveID: "ember-sleep")
        ],
        evolution: Evolution(intoSpeciesID: "ignifox", atLevel: 16)
    )

    private static let ignifox = CreatureSpecies(
        id: "ignifox",
        name: "Ignifox",
        dexNumber: 2,
        primaryType: .flame,
        baseStats: Stats(hp: 70, attack: 80, defense: 60, specialAttack: 95, specialDefense: 65, speed: 90),
        emoji: "\u{1F981}", // lion
        description: "Ignifox blazes down woodland trails in streaks of fire and fur.",
        captureRate: 45,
        baseExperienceYield: 155,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "scratch"),
            LevelMove(level: 1,  moveID: "ember"),
            LevelMove(level: 5,  moveID: "growl"),
            LevelMove(level: 10, moveID: "quickjab"),
            LevelMove(level: 16, moveID: "flameburst"),
            LevelMove(level: 22, moveID: "ember-sleep"),
            LevelMove(level: 28, moveID: "rockcharge")
        ],
        evolution: nil
    )

    // MARK: - Aqua line (Tidepaw / Surgekoi)

    private static let tidepaw = CreatureSpecies(
        id: "tidepaw",
        name: "Tidepaw",
        dexNumber: 3,
        primaryType: .aqua,
        baseStats: Stats(hp: 50, attack: 50, defense: 55, specialAttack: 55, specialDefense: 55, speed: 40),
        emoji: "\u{1F9A6}", // otter
        description: "A river-dwelling pup with webbed paws and a knack for making splashes.",
        captureRate: 45,
        baseExperienceYield: 62,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 5,  moveID: "bubble"),
            LevelMove(level: 10, moveID: "harden"),
            LevelMove(level: 15, moveID: "bodyslam"),
            LevelMove(level: 20, moveID: "tidalcrash"),
            LevelMove(level: 25, moveID: "mistyveil")
        ],
        evolution: Evolution(intoSpeciesID: "surgekoi", atLevel: 16)
    )

    private static let surgekoi = CreatureSpecies(
        id: "surgekoi",
        name: "Surgekoi",
        dexNumber: 4,
        primaryType: .aqua,
        baseStats: Stats(hp: 80, attack: 65, defense: 75, specialAttack: 90, specialDefense: 80, speed: 60),
        emoji: "\u{1F41F}", // fish
        description: "Rainbow-finned river guardian that conjures walls of churning water.",
        captureRate: 45,
        baseExperienceYield: 158,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "bubble"),
            LevelMove(level: 5,  moveID: "growl"),
            LevelMove(level: 10, moveID: "harden"),
            LevelMove(level: 16, moveID: "tidalcrash"),
            LevelMove(level: 22, moveID: "mistyveil"),
            LevelMove(level: 28, moveID: "recover")
        ],
        evolution: nil
    )

    // MARK: - Leaf line (Sprigling / Verdantor)

    private static let sprigling = CreatureSpecies(
        id: "sprigling",
        name: "Sprigling",
        dexNumber: 5,
        primaryType: .leaf,
        baseStats: Stats(hp: 55, attack: 45, defense: 55, specialAttack: 55, specialDefense: 60, speed: 35),
        emoji: "\u{1F331}", // seedling
        description: "A tiny sapling-spirit that hums to itself while photosynthesising.",
        captureRate: 45,
        baseExperienceYield: 62,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 5,  moveID: "vinewhip"),
            LevelMove(level: 10, moveID: "harden"),
            LevelMove(level: 15, moveID: "venomfang"),
            LevelMove(level: 20, moveID: "leafslice"),
            LevelMove(level: 25, moveID: "recover")
        ],
        evolution: Evolution(intoSpeciesID: "verdantor", atLevel: 16)
    )

    private static let verdantor = CreatureSpecies(
        id: "verdantor",
        name: "Verdantor",
        dexNumber: 6,
        primaryType: .leaf,
        secondaryType: .stone,
        baseStats: Stats(hp: 85, attack: 80, defense: 95, specialAttack: 75, specialDefense: 85, speed: 45),
        emoji: "\u{1F332}", // evergreen tree
        description: "A lumbering grove-lord whose bark is laced with mineral-hard ridges.",
        captureRate: 45,
        baseExperienceYield: 160,
        growthRate: .mediumSlow,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "vinewhip"),
            LevelMove(level: 5,  moveID: "growl"),
            LevelMove(level: 10, moveID: "harden"),
            LevelMove(level: 16, moveID: "leafslice"),
            LevelMove(level: 22, moveID: "pebbletoss"),
            LevelMove(level: 28, moveID: "boulderdrop")
        ],
        evolution: nil
    )

    // MARK: - Spark friend (Voltkit)

    private static let voltkit = CreatureSpecies(
        id: "voltkit",
        name: "Voltkit",
        dexNumber: 7,
        primaryType: .spark,
        baseStats: Stats(hp: 40, attack: 45, defense: 40, specialAttack: 65, specialDefense: 45, speed: 80),
        emoji: "\u{1F43E}", // paw print-ish
        description: "Fur stands on end; a single pat is a guaranteed static shock.",
        captureRate: 120,
        baseExperienceYield: 70,
        growthRate: .mediumFast,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 4,  moveID: "zap"),
            LevelMove(level: 9,  moveID: "quickjab"),
            LevelMove(level: 14, moveID: "bodyslam"),
            LevelMove(level: 19, moveID: "thunderstrike"),
            LevelMove(level: 24, moveID: "harden")
        ],
        evolution: nil
    )

    // MARK: - Stone common (Boulderling)

    private static let boulderling = CreatureSpecies(
        id: "boulderling",
        name: "Boulderling",
        dexNumber: 8,
        primaryType: .stone,
        baseStats: Stats(hp: 60, attack: 70, defense: 90, specialAttack: 30, specialDefense: 45, speed: 25),
        emoji: "\u{1FAA8}", // rock
        description: "A suspicious rock that sprouts stubby legs when nobody is looking.",
        captureRate: 180,
        baseExperienceYield: 60,
        growthRate: .mediumFast,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "harden"),
            LevelMove(level: 5,  moveID: "pebbletoss"),
            LevelMove(level: 10, moveID: "growl"),
            LevelMove(level: 15, moveID: "bodyslam"),
            LevelMove(level: 20, moveID: "boulderdrop"),
            LevelMove(level: 25, moveID: "rockcharge")
        ],
        evolution: nil
    )

    // MARK: - Gust uncommon (Zephyrix)

    private static let zephyrix = CreatureSpecies(
        id: "zephyrix",
        name: "Zephyrix",
        dexNumber: 9,
        primaryType: .gust,
        baseStats: Stats(hp: 55, attack: 50, defense: 45, specialAttack: 75, specialDefense: 55, speed: 95),
        emoji: "\u{1F54A}", // dove
        description: "A sleek sky-courser whose wingbeats carve ribbons of visible wind.",
        captureRate: 90,
        baseExperienceYield: 95,
        growthRate: .mediumFast,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 5,  moveID: "breeze"),
            LevelMove(level: 10, moveID: "quickjab"),
            LevelMove(level: 15, moveID: "gustflurry"),
            LevelMove(level: 20, moveID: "cyclonecut"),
            LevelMove(level: 25, moveID: "mistyveil")
        ],
        evolution: nil
    )

    // MARK: - Rare dual types

    private static let pyrolamb = CreatureSpecies(
        id: "pyrolamb",
        name: "Pyrolamb",
        dexNumber: 10,
        primaryType: .flame,
        secondaryType: .leaf,
        baseStats: Stats(hp: 65, attack: 70, defense: 60, specialAttack: 80, specialDefense: 70, speed: 55),
        emoji: "\u{1F411}", // sheep
        description: "A woolly herbivore whose fleece smoulders after grazing in sun-scorched fields.",
        captureRate: 75,
        baseExperienceYield: 130,
        growthRate: .mediumFast,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "growl"),
            LevelMove(level: 5,  moveID: "vinewhip"),
            LevelMove(level: 10, moveID: "ember"),
            LevelMove(level: 15, moveID: "harden"),
            LevelMove(level: 20, moveID: "flameburst"),
            LevelMove(level: 25, moveID: "leafslice")
        ],
        evolution: nil
    )

    private static let frostgale = CreatureSpecies(
        id: "frostgale",
        name: "Frostgale",
        dexNumber: 11,
        primaryType: .aqua,
        secondaryType: .gust,
        baseStats: Stats(hp: 60, attack: 55, defense: 60, specialAttack: 95, specialDefense: 75, speed: 85),
        emoji: "\u{2744}", // snowflake
        description: "Exhales a rime-chilled breeze that hangs in the air long after it passes.",
        captureRate: 60,
        baseExperienceYield: 150,
        growthRate: .mediumFast,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "bubble"),
            LevelMove(level: 5,  moveID: "breeze"),
            LevelMove(level: 10, moveID: "growl"),
            LevelMove(level: 15, moveID: "mistyveil"),
            LevelMove(level: 20, moveID: "tidalcrash"),
            LevelMove(level: 25, moveID: "cyclonecut")
        ],
        evolution: nil
    )

    private static let thunderock = CreatureSpecies(
        id: "thunderock",
        name: "Thunderock",
        dexNumber: 12,
        primaryType: .spark,
        secondaryType: .stone,
        baseStats: Stats(hp: 80, attack: 95, defense: 95, specialAttack: 70, specialDefense: 80, speed: 50),
        emoji: "\u{1F5FB}", // mountain
        description: "A storm-battered crag that walks; every footfall echoes with rolling thunder.",
        captureRate: 45,
        baseExperienceYield: 200,
        growthRate: .slow,
        learnset: [
            LevelMove(level: 1,  moveID: "tackle"),
            LevelMove(level: 1,  moveID: "harden"),
            LevelMove(level: 5,  moveID: "pebbletoss"),
            LevelMove(level: 10, moveID: "zap"),
            LevelMove(level: 15, moveID: "bodyslam"),
            LevelMove(level: 20, moveID: "boulderdrop"),
            LevelMove(level: 25, moveID: "thunderstrike")
        ],
        evolution: nil
    )

    // MARK: - Registry

    public static let all: [CreatureSpecies] = [
        flarepup, ignifox,
        tidepaw, surgekoi,
        sprigling, verdantor,
        voltkit,
        boulderling,
        zephyrix,
        pyrolamb, frostgale, thunderock
    ]

    public static let byID: [String: CreatureSpecies] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    /// Look up a species by slug. Trapping on miss is acceptable since
    /// IDs are static, compiled-in constants.
    public static func species(_ id: String) -> CreatureSpecies {
        guard let s = byID[id] else {
            preconditionFailure("Unknown species id: \(id)")
        }
        return s
    }
}
