import Foundation

/// Integer 2D grid coordinate. Origin is the top-left of a map, with
/// `x` increasing east and `y` increasing south.
public struct GridPosition: Codable, Sendable, Hashable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public static let zero = GridPosition(x: 0, y: 0)

    public static func + (_ a: GridPosition, _ b: GridPosition) -> GridPosition {
        GridPosition(x: a.x + b.x, y: a.y + b.y)
    }
}

/// A cardinal direction. Movement deltas assume an origin-at-top-left
/// grid: north decreases `y`, south increases `y`.
public enum Direction: String, Codable, Sendable, CaseIterable {
    case north
    case south
    case east
    case west

    /// Unit offset to apply to a `GridPosition` to face / walk in this
    /// direction.
    public var delta: GridPosition {
        switch self {
        case .north: return GridPosition(x:  0, y: -1)
        case .south: return GridPosition(x:  0, y:  1)
        case .east:  return GridPosition(x:  1, y:  0)
        case .west:  return GridPosition(x: -1, y:  0)
        }
    }

    /// The direction that points the other way.
    public var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east:  return .west
        case .west:  return .east
        }
    }

    /// Arrow glyph used by the retro renderer to show the player facing.
    public var arrow: String {
        switch self {
        case .north: return "\u{2B06}" // up
        case .south: return "\u{2B07}" // down
        case .east:  return "\u{27A1}" // right
        case .west:  return "\u{2B05}" // left
        }
    }
}
