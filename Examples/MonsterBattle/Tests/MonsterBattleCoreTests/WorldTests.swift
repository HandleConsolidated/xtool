import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("World maps and movement")
struct WorldTests {

    @Test func starterTownTileCountMatchesDimensions() {
        let map = MapData.starterTown
        #expect(map.tiles.count == map.width * map.height)
    }

    @Test func route1TileCountMatchesDimensions() {
        let map = MapData.route1
        #expect(map.tiles.count == map.width * map.height)
    }

    @Test func bumpingIntoATreeIsBlockedButFacingStillUpdates() {
        // starterTown spawn is (6, 5). The west-bound spawn row is padded
        // with trees at x=0 and x=11; grass and path fill the interior.
        // Let's try stepping into the tree border on the left side of row 5
        // by placing the player at (1, 5) and walking west into (0, 5).
        var world = WorldState(
            currentMapID: MapData.starterTown.id,
            playerPosition: GridPosition(x: 1, y: 5),
            playerFacing: .south
        )
        let map = MapData.starterTown
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let result = MovementResolver.step(world: world, on: map, direction: .west, rng: &rng)
        #expect(result.newPosition == GridPosition(x: 1, y: 5))
        #expect(result.newFacing == .west)
        if case .blocked = result.event {
            // good
        } else {
            Issue.record("expected .blocked, got \(String(describing: result.event))")
        }
        // Apply as the caller would and make sure position didn't drift.
        world.playerFacing = result.newFacing
        world.playerPosition = result.newPosition
        #expect(world.playerPosition == GridPosition(x: 1, y: 5))
    }

    @Test func walkingOntoAWarpEmitsWarpedEvent() {
        // starterTown has a door warp at (6, 0). Approach it from (6, 1)
        // walking north.
        let world = WorldState(
            currentMapID: MapData.starterTown.id,
            playerPosition: GridPosition(x: 6, y: 1),
            playerFacing: .north
        )
        let map = MapData.starterTown
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let result = MovementResolver.step(world: world, on: map, direction: .north, rng: &rng)
        #expect(result.newPosition == GridPosition(x: 6, y: 0))
        if case .warped(let warp) = result.event {
            #expect(warp.toMap == "route1")
        } else {
            Issue.record("expected .warped, got \(String(describing: result.event))")
        }
    }

    @Test func tallGrassOccasionallyTriggersAnEncounterAcrossSeeds() {
        // route1 row 1: `T,,,:::,,,,,T` — tall grass at columns 4, 5, 6.
        // Starting at (3, 1) and walking east steps onto tall grass at (4, 1).
        let map = MapData.route1
        var encounters = 0
        for seed in UInt64(1)..<UInt64(60) {
            let world = WorldState(
                currentMapID: map.id,
                playerPosition: GridPosition(x: 3, y: 1),
                playerFacing: .east
            )
            var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
            let result = MovementResolver.step(world: world, on: map, direction: .east, rng: &rng)
            if case .wildEncounter = result.event { encounters += 1 }
        }
        #expect(encounters >= 1)
    }

    @Test func walkingIntoUnbeatenTrainerNPCEmitsNpcEncounter() {
        // The bug catcher on route1 sits at (10, 3). Approach from (10, 4).
        let world = WorldState(
            currentMapID: MapData.route1.id,
            playerPosition: GridPosition(x: 10, y: 4),
            playerFacing: .north
        )
        let map = MapData.route1
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 1)
        let result = MovementResolver.step(world: world, on: map, direction: .north, rng: &rng)
        if case .npcEncounter(let npcID) = result.event {
            #expect(npcID == "route1_bugcatcher")
        } else {
            Issue.record("expected .npcEncounter, got \(String(describing: result.event))")
        }
        // Position must not advance onto the NPC tile.
        #expect(result.newPosition == GridPosition(x: 10, y: 4))
    }
}
