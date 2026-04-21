import Foundation

/// A single cell type in an overworld map grid. Tiles are purely spatial;
/// entities like NPCs and warps are stored alongside the tile grid in
/// `GameMap`.
public enum Tile: String, Codable, Sendable, CaseIterable, Hashable {
    case path
    case grass
    case tallGrass
    case water
    case tree
    case wall
    case flower
    case sand
    case door
    case sign
    case npcTile

    /// True when the player can step onto this tile (before considering
    /// NPCs or warps). NPC-occupied tiles are handled separately by
    /// `GameMap.isWalkable(at:)`.
    public var isWalkable: Bool {
        switch self {
        case .path, .grass, .tallGrass, .flower, .sand, .door:
            return true
        case .water, .tree, .wall, .sign, .npcTile:
            return false
        }
    }

    /// True only for tall grass — the tile that may roll wild encounters.
    public var triggersEncounter: Bool {
        self == .tallGrass
    }

    /// Emoji glyph used by the retro terminal renderer.
    public var emoji: String {
        switch self {
        case .path:      return "\u{2B1C}" // white large square (light dirt)
        case .grass:     return "\u{1F33F}" // herb
        case .tallGrass: return "\u{1F33E}" // rice-stalk
        case .water:     return "\u{1F30A}" // water wave
        case .tree:      return "\u{1F333}" // deciduous tree
        case .wall:      return "\u{1F9F1}" // brick
        case .flower:    return "\u{1F337}" // tulip
        case .sand:      return "\u{1F7E8}" // yellow square
        case .door:      return "\u{1F6AA}" // door
        case .sign:      return "\u{1FAA7}" // placard
        case .npcTile:   return "\u{2753}"  // question mark (placeholder)
        }
    }

    /// RGB triple in the 0...1 range, for renderers that prefer colour
    /// over glyphs. Values are hand-picked for readability on a dark
    /// background.
    public var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .path:      return (0.82, 0.72, 0.53)
        case .grass:     return (0.36, 0.72, 0.36)
        case .tallGrass: return (0.22, 0.55, 0.22)
        case .water:     return (0.25, 0.45, 0.85)
        case .tree:      return (0.15, 0.40, 0.20)
        case .wall:      return (0.45, 0.45, 0.50)
        case .flower:    return (0.95, 0.65, 0.80)
        case .sand:      return (0.95, 0.87, 0.60)
        case .door:      return (0.55, 0.35, 0.20)
        case .sign:      return (0.70, 0.55, 0.30)
        case .npcTile:   return (0.90, 0.90, 0.90)
        }
    }
}
