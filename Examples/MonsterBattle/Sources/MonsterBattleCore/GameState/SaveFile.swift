import Foundation

/// A complete, self-contained snapshot of the game that can round-trip
/// through JSON. The world catalogue (`MapData`) is compiled in and not
/// stored here; only mutable per-save state lives on `WorldState`.
public struct SaveFile: Codable, Sendable {
    /// Bump this whenever the on-disk schema changes incompatibly.
    public static let currentVersion = 1

    /// Schema version the save was written with.
    public var version: Int
    /// Wall-clock time the save was written.
    public var savedAt: Date
    /// The player profile.
    public var trainer: Trainer
    /// World-exploration state (current map, position, per-map flags).
    public var world: WorldState
    /// Seed used to re-initialize the next battle/encounter RNG so a
    /// load produces the same experience as a no-crash session would.
    public var rngSeed: UInt64

    public init(
        trainer: Trainer,
        world: WorldState,
        rngSeed: UInt64 = UInt64.random(in: 1...UInt64.max)
    ) {
        self.version = Self.currentVersion
        self.savedAt = Date()
        self.trainer = trainer
        self.world = world
        self.rngSeed = rngSeed
    }
}
