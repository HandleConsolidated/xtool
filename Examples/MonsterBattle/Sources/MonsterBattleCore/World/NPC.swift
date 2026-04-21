import Foundation

/// A trainer's party definition for NPC battles.
public struct TrainerParty: Codable, Sendable, Hashable {
    /// One slot of a trainer's team. Level and speciesID only — IVs and
    /// moves are synthesized from the species learnset at battle time
    /// via `MonsterInstance.wild(...)` or an equivalent factory.
    public struct Member: Codable, Sendable, Hashable {
        public var speciesID: String
        public var level: Int

        public init(speciesID: String, level: Int) {
            self.speciesID = speciesID
            self.level = level
        }
    }

    /// Human-readable trainer class, e.g. "Bug Catcher", "Hiker", "Rival".
    public var classTitle: String
    public var members: [Member]
    /// Prize money awarded to the player on victory.
    public var prizeMoney: Int

    public init(classTitle: String, members: [Member], prizeMoney: Int) {
        self.classTitle = classTitle
        self.members = members
        self.prizeMoney = prizeMoney
    }
}

/// A non-player character placed on a map tile. NPCs may carry dialog
/// lines and optionally a `TrainerParty` that triggers a battle when the
/// player attempts to step onto them or interacts with them face-to-face.
public struct NPC: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var position: GridPosition
    public var facing: Direction
    public var emoji: String
    public var name: String
    public var dialog: [String]
    public var postBattleDialog: [String]
    public var trainer: TrainerParty?
    public var hasBeenDefeated: Bool

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        id: String,
        position: GridPosition,
        facing: Direction = .south,
        emoji: String,
        name: String,
        dialog: [String],
        postBattleDialog: [String] = [],
        trainer: TrainerParty? = nil,
        hasBeenDefeated: Bool = false
    ) {
        self.id = id
        self.position = position
        self.facing = facing
        self.emoji = emoji
        self.name = name
        self.dialog = dialog
        self.postBattleDialog = postBattleDialog
        self.trainer = trainer
        self.hasBeenDefeated = hasBeenDefeated
    }
}
