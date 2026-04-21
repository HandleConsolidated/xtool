import Foundation

/// Canonical catalogue of every move the game knows about. All entries
/// are original content. IDs are lowercase slugs; lookups assume they
/// are stable.
public enum MoveDex {

    // MARK: - Generic physical (neutral-ish; typed as flame's opposite
    // would be odd so we tag them with a sensible element when needed).

    private static let tackle = Move(
        id: "tackle",
        name: "Tackle",
        element: .stone, // a physical body-check; neutral vibes
        category: .physical,
        power: 40,
        accuracy: 100,
        maxPP: 35,
        priority: 0,
        description: "A full-body charge at the target."
    )

    private static let bodyslam = Move(
        id: "bodyslam",
        name: "Body Slam",
        element: .stone,
        category: .physical,
        power: 65,
        accuracy: 100,
        maxPP: 15,
        priority: 0,
        description: "Drops the user's weight onto the target. May paralyze.",
        effect: MoveEffect(chance: 10, kind: .applyStatus(.paralyze))
    )

    private static let scratch = Move(
        id: "scratch",
        name: "Scratch",
        element: .stone,
        category: .physical,
        power: 40,
        accuracy: 100,
        maxPP: 35,
        priority: 0,
        description: "A quick claw swipe."
    )

    private static let quickjab = Move(
        id: "quickjab",
        name: "Quick Jab",
        element: .stone,
        category: .physical,
        power: 40,
        accuracy: 100,
        maxPP: 30,
        priority: 1,
        description: "A lightning-fast jab that almost always strikes first."
    )

    // MARK: - Flame

    private static let ember = Move(
        id: "ember",
        name: "Ember",
        element: .flame,
        category: .special,
        power: 40,
        accuracy: 95,
        maxPP: 25,
        description: "Sparks of fire lick at the target. May burn.",
        effect: MoveEffect(chance: 10, kind: .applyStatus(.burn))
    )

    private static let flameburst = Move(
        id: "flameburst",
        name: "Flame Burst",
        element: .flame,
        category: .special,
        power: 80,
        accuracy: 95,
        maxPP: 15,
        description: "A compact explosion of flame engulfs the target."
    )

    // Sleep-inducing flame move requested in spec: ember-sleep
    private static let emberSleep = Move(
        id: "ember-sleep",
        name: "Drowsy Ember",
        element: .flame,
        category: .status,
        power: 0,
        accuracy: 75,
        maxPP: 10,
        description: "A lulling warmth that tries to put the target to sleep.",
        effect: MoveEffect(chance: 100, kind: .applyStatus(.sleep))
    )

    // MARK: - Aqua

    private static let bubble = Move(
        id: "bubble",
        name: "Bubble",
        element: .aqua,
        category: .special,
        power: 40,
        accuracy: 95,
        maxPP: 30,
        description: "Shoots a stream of bubbles. May lower opponent speed.",
        effect: MoveEffect(
            chance: 10,
            kind: .statChange(target: .opponent, change: StatChange(stat: .speed, delta: -1))
        )
    )

    private static let tidalcrash = Move(
        id: "tidalcrash",
        name: "Tidal Crash",
        element: .aqua,
        category: .special,
        power: 85,
        accuracy: 90,
        maxPP: 10,
        description: "A breaking wave slams down with great force."
    )

    // MARK: - Leaf

    private static let vinewhip = Move(
        id: "vinewhip",
        name: "Vine Whip",
        element: .leaf,
        category: .physical,
        power: 40,
        accuracy: 100,
        maxPP: 25,
        description: "Lashes the target with a conjured vine."
    )

    private static let leafslice = Move(
        id: "leafslice",
        name: "Leaf Slice",
        element: .leaf,
        category: .physical,
        power: 70,
        accuracy: 100,
        maxPP: 15,
        description: "Razor-edged leaves carve at the target."
    )

    // MARK: - Spark

    private static let zap = Move(
        id: "zap",
        name: "Zap",
        element: .spark,
        category: .special,
        power: 40,
        accuracy: 100,
        maxPP: 30,
        description: "A small jolt of electricity. May paralyze.",
        effect: MoveEffect(chance: 10, kind: .applyStatus(.paralyze))
    )

    private static let thunderstrike = Move(
        id: "thunderstrike",
        name: "Thunder Strike",
        element: .spark,
        category: .special,
        power: 85,
        accuracy: 90,
        maxPP: 10,
        description: "A crackling bolt tears into the foe. May paralyze.",
        effect: MoveEffect(chance: 20, kind: .applyStatus(.paralyze))
    )

    // MARK: - Stone

    private static let pebbletoss = Move(
        id: "pebbletoss",
        name: "Pebble Toss",
        element: .stone,
        category: .physical,
        power: 40,
        accuracy: 95,
        maxPP: 30,
        description: "Hurls a handful of stones at the target."
    )

    private static let boulderdrop = Move(
        id: "boulderdrop",
        name: "Boulder Drop",
        element: .stone,
        category: .physical,
        power: 80,
        accuracy: 85,
        maxPP: 10,
        description: "Slams the foe with a massive stone."
    )

    // MARK: - Gust

    private static let breeze = Move(
        id: "breeze",
        name: "Breeze",
        element: .gust,
        category: .special,
        power: 40,
        accuracy: 100,
        maxPP: 30,
        description: "A stiff wind buffets the target."
    )

    private static let cyclonecut = Move(
        id: "cyclonecut",
        name: "Cyclone Cut",
        element: .gust,
        category: .special,
        power: 75,
        accuracy: 95,
        maxPP: 15,
        description: "A spiralling blade of wind shears the target."
    )

    // MARK: - Status moves

    private static let growl = Move(
        id: "growl",
        name: "Growl",
        element: .stone,
        category: .status,
        power: 0,
        accuracy: 100,
        maxPP: 40,
        description: "An intimidating growl lowers the target's attack.",
        effect: MoveEffect(
            chance: 100,
            kind: .statChange(target: .opponent, change: StatChange(stat: .attack, delta: -1))
        )
    )

    private static let harden = Move(
        id: "harden",
        name: "Harden",
        element: .stone,
        category: .status,
        power: 0,
        accuracy: 0, // never misses
        maxPP: 30,
        description: "The user stiffens, raising its defense.",
        effect: MoveEffect(
            chance: 100,
            kind: .statChange(target: .user, change: StatChange(stat: .defense, delta: 1))
        )
    )

    private static let venomfang = Move(
        id: "venomfang",
        name: "Venom Fang",
        element: .leaf,
        category: .physical,
        power: 50,
        accuracy: 100,
        maxPP: 15,
        description: "A toxic bite that often poisons the target.",
        effect: MoveEffect(chance: 40, kind: .applyStatus(.poison))
    )

    // Additional support / utility moves to round out the roster.

    private static let mistyveil = Move(
        id: "mistyveil",
        name: "Misty Veil",
        element: .aqua,
        category: .status,
        power: 0,
        accuracy: 0,
        maxPP: 20,
        description: "A veil of mist raises the user's evasion.",
        effect: MoveEffect(
            chance: 100,
            kind: .statChange(target: .user, change: StatChange(stat: .evasion, delta: 1))
        )
    )

    private static let recover = Move(
        id: "recover",
        name: "Mend",
        element: .leaf,
        category: .status,
        power: 0,
        accuracy: 0,
        maxPP: 10,
        description: "The user knits itself back together, restoring half its HP.",
        effect: MoveEffect(chance: 100, kind: .heal(fraction: 0.5))
    )

    private static let rockcharge = Move(
        id: "rockcharge",
        name: "Rock Charge",
        element: .stone,
        category: .physical,
        power: 90,
        accuracy: 85,
        maxPP: 10,
        description: "A reckless charge that damages the user.",
        effect: MoveEffect(chance: 100, kind: .recoil(fraction: 0.25))
    )

    private static let gustflurry = Move(
        id: "gustflurry",
        name: "Gust Flurry",
        element: .gust,
        category: .physical,
        power: 20,
        accuracy: 90,
        maxPP: 20,
        description: "Rapid wind-backed strikes that land 2-5 times.",
        effect: MoveEffect(chance: 100, kind: .multiHit(min: 2, max: 5))
    )

    // MARK: - Registry

    public static let all: [Move] = [
        tackle, bodyslam, scratch, quickjab,
        ember, flameburst, emberSleep,
        bubble, tidalcrash,
        vinewhip, leafslice,
        zap, thunderstrike,
        pebbletoss, boulderdrop,
        breeze, cyclonecut,
        growl, harden, venomfang,
        mistyveil, recover, rockcharge, gustflurry
    ]

    public static let byID: [String: Move] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    /// Look up a move by id. Trapping the missing case is acceptable
    /// because move IDs are compiled-in constants.
    public static func move(_ id: String) -> Move {
        guard let move = byID[id] else {
            preconditionFailure("Unknown move id: \(id)")
        }
        return move
    }
}
