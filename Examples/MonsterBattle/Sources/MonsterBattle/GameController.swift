import Foundation
import Combine
import MonsterBattleCore

/// Top-level observable game state. SwiftUI views bind to this via
/// `@StateObject` / `@EnvironmentObject`. All mutation happens on the
/// main actor so `@Published` updates are always delivered on the UI
/// thread.
@MainActor
public final class GameController: ObservableObject {

    /// High-level UI scene the app is currently showing. Does not
    /// replace fine-grained navigation inside a scene (e.g. menus
    /// within the party screen) — it only decides *which top-level
    /// screen is visible*.
    public enum Scene: Sendable, Equatable {
        case mainMenu
        case overworld
        case battle
        case party
        case bag
        case dialog(lines: [String])
        case gameOver
    }

    // MARK: - Published state

    @Published public var trainer: Trainer
    @Published public var world: WorldState
    @Published public private(set) var scene: Scene
    /// Human-readable save / load error for UI display. `nil` when the
    /// last save / load attempt succeeded or no attempt has been made.
    @Published public private(set) var saveError: String?

    /// Description of the battle that should be started next. The UI
    /// creates a `BattleController` from this and calls
    /// `clearPendingBattle()` once it has taken ownership.
    @Published public private(set) var pendingBattle: PendingBattle?

    /// Transient description of a battle the engine should start.
    public struct PendingBattle: Sendable, Equatable {
        public enum Kind: Sendable, Equatable {
            case wild(MonsterInstance)
            case trainer(npcID: String, classTitle: String, name: String, party: [MonsterInstance])
        }
        public var kind: Kind
        public var seed: UInt64
    }

    // MARK: - Non-published collaborators

    /// Shared deterministic RNG. Battle/encounter systems that want
    /// determinism across a load boundary should pull from this stream.
    public var rng: SeededRandomNumberGenerator

    /// On-disk save manager. `nil` when the platform refused to give us
    /// an Application Support directory (unlikely, but don't crash the
    /// app — surface via `saveError`).
    public let saveManager: SaveManager?

    // MARK: - Init

    /// Fresh-game defaults: empty trainer, standing on `starterTown`'s
    /// spawn tile facing south, viewing the main menu.
    public init() {
        let spawn = MapData.starterTown.spawn
        self.trainer = Trainer(name: "")
        self.world = WorldState(
            currentMapID: MapData.starterTown.id,
            playerPosition: spawn,
            playerFacing: .south,
            mapState: [:]
        )
        self.scene = .mainMenu
        self.rng = SeededRandomNumberGenerator(seed: UInt64.random(in: 1...UInt64.max))
        self.saveManager = (try? SaveManager.default())
    }

    // MARK: - New game

    /// Stamp a fresh trainer profile into place, hand out a starter at
    /// level 5, seed the bag, and drop the player at the starter town
    /// spawn. Switches the scene to `.overworld`.
    public func newGame(trainerName: String, starterSpeciesID: String) {
        var rngExistential: any RandomNumberGenerator = rng
        let starter = Starters.monster(speciesID: starterSpeciesID, rng: &rngExistential)
        if let seeded = rngExistential as? SeededRandomNumberGenerator {
            rng = seeded
        }

        var newTrainer = Trainer(
            name: trainerName,
            money: 1000
        )
        newTrainer.addMonster(starter)
        newTrainer.bag.add("monsterOrb", count: 5)
        newTrainer.bag.add("potion", count: 3)
        newTrainer.bag.add("antidote", count: 1)
        trainer = newTrainer

        let spawn = MapData.starterTown.spawn
        world = WorldState(
            currentMapID: MapData.starterTown.id,
            playerPosition: spawn,
            playerFacing: .south,
            mapState: [:]
        )
        scene = .overworld
        saveError = nil
    }

    // MARK: - Scene helpers

    /// Convenience setter so views don't have to route through a mutator.
    public func present(scene: Scene) {
        self.scene = scene
    }

    /// Show a dialog with the given lines. If `lines` is empty, the
    /// caller probably wants to stay in `.overworld`; we just no-op.
    public func pushDialog(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        scene = .dialog(lines: lines)
    }

    /// Dismiss a dialog, returning to the overworld. Safe to call even
    /// when the current scene isn't a dialog.
    public func dismissDialog() {
        scene = .overworld
    }

    // MARK: - Save / load

    /// Save the current state to `slot`. Errors are caught and surfaced
    /// on `saveError`; callers should observe that to render a toast.
    public func save(slot: Int = 0) {
        guard let manager = saveManager else {
            saveError = "Save system unavailable."
            return
        }
        let file = SaveFile(trainer: trainer, world: world, rngSeed: rng.next())
        saveError = nil
        Task { [file] in
            do {
                try await manager.save(file, slot: slot)
            } catch let error as SaveError {
                await MainActor.run { self.saveError = Self.describe(error) }
            } catch {
                await MainActor.run { self.saveError = "\(error)" }
            }
        }
    }

    /// Load `slot` into `trainer` / `world` / `rng`. On success, switch
    /// the scene to `.overworld`. On failure, populate `saveError` and
    /// leave the in-memory state untouched.
    public func loadSave(slot: Int = 0) {
        guard let manager = saveManager else {
            saveError = "Save system unavailable."
            return
        }
        saveError = nil
        Task {
            do {
                let file = try await manager.load(slot: slot)
                await MainActor.run { self.apply(loaded: file) }
            } catch let error as SaveError {
                await MainActor.run { self.saveError = Self.describe(error) }
            } catch {
                await MainActor.run { self.saveError = "\(error)" }
            }
        }
    }

    private func apply(loaded file: SaveFile) {
        trainer = file.trainer
        world = file.world
        rng = SeededRandomNumberGenerator(seed: file.rngSeed)
        scene = .overworld
        saveError = nil
    }

    private static func describe(_ error: SaveError) -> String {
        switch error {
        case .fileNotFound:
            return "No save file in that slot."
        case .decodeFailed(let detail):
            return "Save file is corrupt: \(detail)"
        case .encodeFailed(let detail):
            return "Couldn't encode save: \(detail)"
        case .ioFailed(let detail):
            return "I/O error: \(detail)"
        case .incompatibleVersion(let v):
            return "Save was written by a newer game version (v\(v))."
        }
    }

    // MARK: - Inventory / money

    public func giveItem(_ itemID: String, count: Int = 1) {
        trainer.bag.add(itemID, count: count)
    }

    public func giveMoney(_ amount: Int) {
        trainer.awardMoney(amount)
    }

    // MARK: - Movement glue

    /// Resolve a single-step movement in the overworld. Swaps in scenes
    /// for warps / wild battles / NPC encounters; for plain moves just
    /// updates the player position and facing.
    public func tryMove(direction: Direction) {
        guard let map = MapData.all.first(where: { $0.id == world.currentMapID }) else {
            return
        }
        var rngExistential: any RandomNumberGenerator = rng
        let result = MovementResolver.step(
            world: world,
            on: map,
            direction: direction,
            rng: &rngExistential
        )
        if let seeded = rngExistential as? SeededRandomNumberGenerator {
            rng = seeded
        }

        // Facing is always updated even if the move was blocked.
        var nextWorld = world
        nextWorld.playerFacing = result.newFacing
        nextWorld.playerPosition = result.newPosition

        switch result.event {
        case .none, .moved, .blocked:
            world = nextWorld

        case .warped(let warp):
            nextWorld.currentMapID = warp.toMap
            nextWorld.playerPosition = warp.toPosition
            world = nextWorld

        case .wildEncounter(let monster):
            world = nextWorld
            pendingBattle = PendingBattle(kind: .wild(monster), seed: rng.next())
            scene = .battle

        case .npcEncounter(let npcID):
            world = nextWorld
            guard let npc = locateNPC(id: npcID) else { break }
            if let trainerParty = npc.trainer {
                let party = buildTrainerParty(from: trainerParty)
                pendingBattle = PendingBattle(
                    kind: .trainer(
                        npcID: npc.id,
                        classTitle: trainerParty.classTitle,
                        name: npc.name,
                        party: party
                    ),
                    seed: rng.next()
                )
                scene = .battle
            } else {
                pushDialog(npc.dialog)
            }
        }
    }

    /// Clear the pending battle description once the UI has taken ownership
    /// of it (typically by constructing a `BattleController`).
    public func clearPendingBattle() {
        pendingBattle = nil
    }

    /// Mark an NPC as defeated (called after a trainer battle win).
    public func markNPCDefeated(id: String) {
        var mapState = world.mapState[world.currentMapID] ?? MapState()
        mapState.defeatedNPCs.insert(id)
        world.mapState[world.currentMapID] = mapState
    }

    private func locateNPC(id: String) -> NPC? {
        for map in MapData.all {
            if let npc = map.npcs.first(where: { $0.id == id }) {
                return npc
            }
        }
        return nil
    }

    private func buildTrainerParty(from trainerParty: TrainerParty) -> [MonsterInstance] {
        var rngExistential: any RandomNumberGenerator = rng
        var result: [MonsterInstance] = []
        for member in trainerParty.members {
            let species = CreatureDex.species(member.speciesID)
            let monster = MonsterInstance.wild(
                speciesID: species.id,
                level: member.level,
                species: species,
                moves: MoveDex.all,
                rng: &rngExistential
            )
            result.append(monster)
        }
        if let seeded = rngExistential as? SeededRandomNumberGenerator {
            rng = seeded
        }
        return result
    }

    // MARK: - Battle glue

    /// Called by the battle layer when a battle resolves. Merges the
    /// final combatant monsters back into the party, handles whiteout,
    /// and routes to the appropriate next scene.
    public func onBattleEnded(outcome: BattleOutcome, finalState: BattleState) {
        // Merge the player party back first so HP / status updates land.
        var party = trainer.party
        for (index, monster) in finalState.player.party.enumerated() where index < party.count {
            party.replace(at: index, with: monster)
        }
        trainer.party = party

        switch outcome {
        case .ongoing:
            // Battle layer shouldn't hand us an ongoing state, but be safe.
            return

        case .playerWon, .fled:
            scene = .overworld

        case .playerLost:
            // Whiteout: teleport home, heal everyone, show a message.
            trainer.healAllMonsters()
            let spawn = MapData.starterTown.spawn
            world.currentMapID = MapData.starterTown.id
            world.playerPosition = spawn
            world.playerFacing = .south
            pushDialog([
                "\(trainer.name.isEmpty ? "You" : trainer.name) blacked out!",
                "You scurry back to Willowvale Town to recover."
            ])

        case .caught:
            // The opponent's active monster becomes the newly-owned one.
            let idx = finalState.opponent.activeIndex
            if finalState.opponent.party.indices.contains(idx) {
                trainer.addMonster(finalState.opponent.party[idx])
            }
            scene = .overworld
        }
    }
}
