import Foundation

/// A map-to-map transition. Doors are `triggerOnStep == true`; signs or
/// ledges use `false` so the player must explicitly interact.
public struct Warp: Codable, Sendable, Hashable {
    public var from: GridPosition
    public var toMap: MapID
    public var toPosition: GridPosition
    public var triggerOnStep: Bool

    public init(
        from: GridPosition,
        toMap: MapID,
        toPosition: GridPosition,
        triggerOnStep: Bool
    ) {
        self.from = from
        self.toMap = toMap
        self.toPosition = toPosition
        self.triggerOnStep = triggerOnStep
    }
}
