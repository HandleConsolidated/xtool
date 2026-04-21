import Foundation

/// The outcome of a single attempted step.
public struct StepResult: Sendable {
    public var newPosition: GridPosition
    public var newFacing: Direction
    public var event: StepEvent?

    public init(newPosition: GridPosition, newFacing: Direction, event: StepEvent?) {
        self.newPosition = newPosition
        self.newFacing = newFacing
        self.event = event
    }
}

/// The high-level "what just happened" classification of a step. Exactly
/// one event is emitted per attempt; callers dispatch on it to show
/// bumps, start battles, transition maps, etc.
public enum StepEvent: Sendable {
    case blocked
    case moved
    case warped(Warp)
    case wildEncounter(MonsterInstance)
    case npcEncounter(npcID: String)
    /// A non-trainer NPC is facing the player; show their dialog.
    case npcTalk(npcID: String)
}

/// Pure computation of the next player state for one step in a given
/// direction. Does not mutate the input `WorldState` — callers apply the
/// returned position/facing themselves so this stays easy to test.
public enum MovementResolver {
    public static func step(
        world: WorldState,
        on map: GameMap,
        direction: Direction,
        rng: inout any RandomNumberGenerator
    ) -> StepResult {
        let currentPosition = world.playerPosition
        let target = currentPosition + direction.delta

        // Out-of-bounds or impassable terrain: still turn, don't move.
        guard let targetTile = map.tile(at: target), targetTile.isWalkable else {
            return StepResult(
                newPosition: currentPosition,
                newFacing: direction,
                event: .blocked
            )
        }

        // NPC in the way. Trainer battles override movement; non-trainer
        // NPCs simply block like a wall (interaction handled by the UI).
        if let npc = map.npc(at: target) {
            let alreadyBeaten: Bool = {
                if let state = world.mapState[map.id], state.defeatedNPCs.contains(npc.id) {
                    return true
                }
                return npc.hasBeenDefeated
            }()
            if npc.trainer != nil, !alreadyBeaten {
                return StepResult(
                    newPosition: currentPosition,
                    newFacing: direction,
                    event: .npcEncounter(npcID: npc.id)
                )
            }
            // Non-trainer NPC (or defeated trainer): talk if they have
            // dialog, otherwise just block like a wall.
            if !npc.dialog.isEmpty {
                return StepResult(
                    newPosition: currentPosition,
                    newFacing: direction,
                    event: .npcTalk(npcID: npc.id)
                )
            }
            return StepResult(
                newPosition: currentPosition,
                newFacing: direction,
                event: .blocked
            )
        }

        // The step is committed — figure out secondary effects.
        if let warp = map.warp(at: target), warp.triggerOnStep {
            return StepResult(
                newPosition: target,
                newFacing: direction,
                event: .warped(warp)
            )
        }

        if targetTile.triggersEncounter,
           let table = map.encounterTable,
           let monster = table.roll(rng: &rng) {
            return StepResult(
                newPosition: target,
                newFacing: direction,
                event: .wildEncounter(monster)
            )
        }

        return StepResult(
            newPosition: target,
            newFacing: direction,
            event: .moved
        )
    }
}
