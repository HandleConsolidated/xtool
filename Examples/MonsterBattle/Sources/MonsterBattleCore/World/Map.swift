import Foundation

/// Unique identifier for a map (e.g. "starterTown", "route1").
public typealias MapID = String

/// A single overworld map: a tile grid plus placed entities (NPCs,
/// warps) and an optional wild-encounter table consulted on tall-grass
/// steps.
public struct GameMap: Codable, Sendable, Hashable, Identifiable {
    public var id: MapID
    public var name: String
    public var width: Int
    public var height: Int
    /// Row-major grid: `tiles[y * width + x]`.
    public var tiles: [Tile]
    public var npcs: [NPC]
    public var warps: [Warp]
    public var encounterTable: EncounterTable?
    public var spawn: GridPosition

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        id: MapID,
        name: String,
        width: Int,
        height: Int,
        tiles: [Tile],
        npcs: [NPC] = [],
        warps: [Warp] = [],
        encounterTable: EncounterTable? = nil,
        spawn: GridPosition
    ) {
        precondition(tiles.count == width * height, "tile count must equal width*height for map \(id)")
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.tiles = tiles
        self.npcs = npcs
        self.warps = warps
        self.encounterTable = encounterTable
        self.spawn = spawn
    }

    /// Returns the tile at `pos`, or nil if `pos` is outside the grid.
    public func tile(at pos: GridPosition) -> Tile? {
        guard pos.x >= 0, pos.x < width, pos.y >= 0, pos.y < height else { return nil }
        return tiles[pos.y * width + pos.x]
    }

    /// True if the player can step onto `pos`: in-bounds, the tile is
    /// walkable, and no NPC currently occupies it.
    public func isWalkable(at pos: GridPosition) -> Bool {
        guard let t = tile(at: pos) else { return false }
        guard t.isWalkable else { return false }
        return npc(at: pos) == nil
    }

    /// Returns the first NPC standing exactly on `pos`, if any.
    public func npc(at pos: GridPosition) -> NPC? {
        npcs.first { $0.position == pos }
    }

    /// Returns the first warp originating at `pos`, if any.
    public func warp(at pos: GridPosition) -> Warp? {
        warps.first { $0.from == pos }
    }
}
