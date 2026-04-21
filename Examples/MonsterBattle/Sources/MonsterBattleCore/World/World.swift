import Foundation

/// Per-map mutable state that persists between visits: chiefly which
/// NPCs the player has already defeated. More fields (cut trees, picked
/// items, etc.) would live here later.
public struct MapState: Codable, Sendable, Hashable {
    public var defeatedNPCs: Set<String>

    public init(defeatedNPCs: Set<String> = []) {
        self.defeatedNPCs = defeatedNPCs
    }
}

/// Top-level save-safe description of the player's overworld progress.
/// Pairing this with the immutable `MapData` catalogue is sufficient to
/// reconstruct the explorable world.
public struct WorldState: Codable, Sendable {
    public var currentMapID: MapID
    public var playerPosition: GridPosition
    public var playerFacing: Direction
    public var mapState: [MapID: MapState]

    public init(
        currentMapID: MapID,
        playerPosition: GridPosition,
        playerFacing: Direction,
        mapState: [MapID: MapState] = [:]
    ) {
        self.currentMapID = currentMapID
        self.playerPosition = playerPosition
        self.playerFacing = playerFacing
        self.mapState = mapState
    }
}
