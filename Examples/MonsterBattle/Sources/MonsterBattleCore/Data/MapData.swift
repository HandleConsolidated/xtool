import Foundation

/// Hand-authored catalogue of the overworld maps. Content-only; runtime
/// mutable state (NPC defeats, player position) lives in `WorldState`.
///
/// Tile shorthand used by `row(_:)`:
/// ```
///   '.' path      ',' grass     ':' tall grass   '~' water
///   'T' tree      '#' wall      '*' flower       's' sand
///   'D' door      'S' sign      'n' npcTile      ' ' (space) path
/// ```
/// `npcTile` is a placeholder character; actual NPCs live in the
/// `npcs` array, but marking their tile in the grid keeps visual
/// authoring honest.
public enum MapData {

    // MARK: - starterTown (12x10)

    public static let starterTown: GameMap = {
        // 12 columns x 10 rows. Door at (6, 0) leading north to route1.
        let width = 12
        let height = 10
        let rows: [[Tile]] = [
            row("TTTTTTDTTTTT"),            // 0  door at (6, 0)
            row("T,,,,,.,,,,T"),            // 1
            row("T,**,,.,,**T"),            // 2
            row("T,,,,,.,,,,T"),            // 3
            row("T,,n,,.,,,,T"),            // 4  elder at (3, 4)
            row("T,,,,..,,,,T"),            // 5  player spawn (6, 5)
            row("T,,,,.,,n,,T"),            // 6  rival at (8, 6)
            row("T,**,.,,,**T"),            // 7
            row("T,,,,.,,,,,T"),            // 8
            row("TTTTTTTTTTTT")             // 9
        ]
        let tiles = flatten(rows: rows, width: width, height: height, mapID: "starterTown")

        let elder = NPC(
            id: "starter_elder",
            position: GridPosition(x: 3, y: 4),
            facing: .south,
            emoji: "\u{1F9D3}", // older person
            name: "Elder Rowen",
            dialog: [
                "Oh! A young trainer!",
                "The world is full of wild monsters just waiting to be befriended.",
                "Head north to Route 1 — but watch the tall grass!"
            ],
            postBattleDialog: [],
            trainer: nil,
            hasBeenDefeated: false
        )

        let rival = NPC(
            id: "starter_rival",
            position: GridPosition(x: 8, y: 6),
            facing: .west,
            emoji: "\u{1F9D1}", // person
            name: "Rival",
            dialog: [
                "Hey! I was looking for you.",
                "Let's see how your partner's doing. Battle me!"
            ],
            postBattleDialog: [
                "Tch — not bad.",
                "I'll train harder. See you on the road!"
            ],
            trainer: TrainerParty(
                classTitle: "Rival",
                members: [
                    TrainerParty.Member(speciesID: "voltkit", level: 5)
                ],
                prizeMoney: 80
            ),
            hasBeenDefeated: false
        )

        let warps = [
            Warp(
                from: GridPosition(x: 6, y: 0),
                toMap: "route1",
                toPosition: GridPosition(x: 5, y: 9),
                triggerOnStep: true
            )
        ]

        return GameMap(
            id: "starterTown",
            name: "Willowvale Town",
            width: width,
            height: height,
            tiles: tiles,
            npcs: [elder, rival],
            warps: warps,
            encounterTable: nil,
            spawn: GridPosition(x: 6, y: 5)
        )
    }()

    // MARK: - route1 (13x11)

    public static let route1: GameMap = {
        // 13 columns x 11 rows. Door at (5, 10) leading south back to
        // starterTown. Two tall-grass patches, one bug-catcher trainer,
        // and a sign near the entrance.
        let width = 13
        let height = 11
        let rows: [[Tile]] = [
            row("TTTTTTTTTTTTT"),           //  0
            row("T,,,:::,,,,,T"),           //  1  tall grass patch A top
            row("T,,::::,,,,,T"),           //  2
            row("T,,:::,,,,n,T"),           //  3  bug catcher at (10, 3)
            row("T,,,,,,,,,,,T"),           //  4
            row("T.........,,T"),           //  5  east-west path
            row("T,,,,,,:::,,T"),           //  6  tall grass patch B
            row("T,,,,,:::::,T"),           //  7
            row("T,,,,,:::,,,T"),           //  8
            row("T,S,,,.,,,,,T"),           //  9  sign at (2, 9)
            row("TTTTTDTTTTTTT")            // 10  door at (5, 10)
        ]
        let tiles = flatten(rows: rows, width: width, height: height, mapID: "route1")

        let bugCatcher = NPC(
            id: "route1_bugcatcher",
            position: GridPosition(x: 10, y: 3),
            facing: .west,
            emoji: "\u{1F575}", // detective / trainer
            name: "Bug Catcher Finn",
            dialog: [
                "Hey! I saw you from the tall grass.",
                "My team's tougher than it looks — let's battle!"
            ],
            postBattleDialog: [
                "Owww... you got me.",
                "Route 1's full of friends. Go make some of your own!"
            ],
            trainer: TrainerParty(
                classTitle: "Bug Catcher",
                members: [
                    TrainerParty.Member(speciesID: "boulderling", level: 4),
                    TrainerParty.Member(speciesID: "sprigling", level: 5)
                ],
                prizeMoney: 60
            ),
            hasBeenDefeated: false
        )

        let sign = NPC(
            id: "route1_sign",
            position: GridPosition(x: 2, y: 9),
            facing: .north,
            emoji: "\u{1FAA7}", // placard
            name: "Route 1 Sign",
            dialog: [
                "ROUTE 1",
                "Mind the tall grass — wild monsters love to hide there!"
            ],
            postBattleDialog: [],
            trainer: nil,
            hasBeenDefeated: false
        )

        let encounters = EncounterTable(
            entries: [
                EncounterTable.Entry(speciesID: "flarepup",    minLevel: 3, maxLevel: 5, weight: 5),
                EncounterTable.Entry(speciesID: "tidepaw",     minLevel: 3, maxLevel: 5, weight: 5),
                EncounterTable.Entry(speciesID: "sprigling",   minLevel: 3, maxLevel: 5, weight: 5),
                EncounterTable.Entry(speciesID: "voltkit",     minLevel: 3, maxLevel: 5, weight: 20),
                EncounterTable.Entry(speciesID: "boulderling", minLevel: 3, maxLevel: 5, weight: 25),
                EncounterTable.Entry(speciesID: "zephyrix",    minLevel: 3, maxLevel: 5, weight: 15),
                EncounterTable.Entry(speciesID: "pyrolamb",    minLevel: 3, maxLevel: 5, weight: 5)
            ],
            encounterChance: 12
        )

        let warps = [
            Warp(
                from: GridPosition(x: 5, y: 10),
                toMap: "starterTown",
                toPosition: GridPosition(x: 6, y: 1),
                triggerOnStep: true
            )
        ]

        return GameMap(
            id: "route1",
            name: "Route 1",
            width: width,
            height: height,
            tiles: tiles,
            npcs: [bugCatcher, sign],
            warps: warps,
            encounterTable: encounters,
            spawn: GridPosition(x: 5, y: 9)
        )
    }()

    // MARK: - Registry

    public static let all: [GameMap] = [starterTown, route1]

    public static let byID: [MapID: GameMap] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    public static func map(_ id: MapID) -> GameMap {
        guard let m = byID[id] else {
            preconditionFailure("Unknown map id: \(id)")
        }
        return m
    }

    // MARK: - Authoring helpers

    /// Parse a row of tile shorthand. See the doc comment on `MapData`
    /// for the character legend.
    private static func row(_ chars: String) -> [Tile] {
        chars.map { ch -> Tile in
            switch ch {
            case ".", " ": return .path
            case ",":      return .grass
            case ":":      return .tallGrass
            case "~":      return .water
            case "T":      return .tree
            case "#":      return .wall
            case "*":      return .flower
            case "s":      return .sand
            case "D":      return .door
            case "S":      return .sign
            case "n":      return .npcTile
            default:
                preconditionFailure("Unknown tile char \(ch)")
            }
        }
    }

    /// Flatten a rectangular grid of rows into a row-major tile array,
    /// trapping on any row that doesn't match the declared width.
    private static func flatten(rows: [[Tile]], width: Int, height: Int, mapID: String) -> [Tile] {
        precondition(rows.count == height, "map \(mapID): expected \(height) rows, got \(rows.count)")
        var out: [Tile] = []
        out.reserveCapacity(width * height)
        for (y, r) in rows.enumerated() {
            precondition(r.count == width, "map \(mapID): row \(y) has \(r.count) tiles, expected \(width)")
            out.append(contentsOf: r)
        }
        return out
    }
}
