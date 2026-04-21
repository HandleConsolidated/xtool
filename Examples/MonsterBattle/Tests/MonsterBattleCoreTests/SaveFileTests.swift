import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("SaveFile / SaveManager persistence")
struct SaveFileTests {

    // MARK: - Helpers

    private func makeMonster(speciesID: String, level: Int, seed: UInt64) -> MonsterInstance {
        var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
        let species = CreatureDex.species(speciesID)
        return MonsterInstance.wild(
            speciesID: speciesID,
            level: level,
            species: species,
            moves: MoveDex.all,
            rng: &rng
        )
    }

    private func makePopulatedSave() -> SaveFile {
        var party = Party()
        _ = party.add(makeMonster(speciesID: "flarepup", level: 5, seed: 1))
        _ = party.add(makeMonster(speciesID: "voltkit", level: 7, seed: 2))

        var storage = MonsterStorage()
        storage.deposit(makeMonster(speciesID: "boulderling", level: 4, seed: 3))

        var bag = Bag()
        bag.add("potion", count: 3)
        bag.add("monsterOrb", count: 2)

        let trainer = Trainer(
            name: "Ash",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            money: 1500,
            party: party,
            storage: storage,
            bag: bag,
            badges: ["boulder"],
            playtimeSeconds: 3600
        )
        let world = WorldState(
            currentMapID: "route1",
            playerPosition: GridPosition(x: 5, y: 9),
            playerFacing: .north,
            mapState: ["route1": MapState(defeatedNPCs: ["route1_bugcatcher"])]
        )
        return SaveFile(trainer: trainer, world: world, rngSeed: 0xDEADBEEF)
    }

    private func makeTempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MonsterBattleTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Tests

    @Test func jsonRoundTripPreservesAllFields() throws {
        let original = makePopulatedSave()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let restored = try decoder.decode(SaveFile.self, from: data)

        #expect(restored.version == original.version)
        #expect(restored.rngSeed == original.rngSeed)
        #expect(restored.trainer.name == original.trainer.name)
        #expect(restored.trainer.id == original.trainer.id)
        #expect(restored.trainer.money == original.trainer.money)
        #expect(restored.trainer.badges == original.trainer.badges)
        #expect(restored.trainer.playtimeSeconds == original.trainer.playtimeSeconds)
        #expect(restored.trainer.party.count == original.trainer.party.count)
        #expect(restored.trainer.party[0].speciesID == original.trainer.party[0].speciesID)
        #expect(restored.trainer.party[1].speciesID == original.trainer.party[1].speciesID)
        #expect(restored.trainer.storage.count == original.trainer.storage.count)
        #expect(restored.trainer.bag.quantity(of: "potion") == original.trainer.bag.quantity(of: "potion"))
        #expect(restored.trainer.bag.quantity(of: "monsterOrb") == original.trainer.bag.quantity(of: "monsterOrb"))
        #expect(restored.world.currentMapID == original.world.currentMapID)
        #expect(restored.world.playerPosition == original.world.playerPosition)
        #expect(restored.world.playerFacing == original.world.playerFacing)
        #expect(
            restored.world.mapState["route1"]?.defeatedNPCs
                == original.world.mapState["route1"]?.defeatedNPCs
        )
    }

    @Test func saveManagerRoundTripsThroughTempDir() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(directoryURL: dir)
        let original = makePopulatedSave()

        try await manager.save(original, slot: 0)
        let reloaded = try await manager.load(slot: 0)

        #expect(reloaded.trainer.name == original.trainer.name)
        #expect(reloaded.trainer.money == original.trainer.money)
        #expect(reloaded.rngSeed == original.rngSeed)
        let slots = await manager.listSlots()
        #expect(slots == [0])
    }

    @Test func corruptFileYieldsDecodeFailed() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(directoryURL: dir)

        // Write garbage to slot 0 directly, bypassing the encoder.
        let slotURL = dir.appendingPathComponent("save_00.json", isDirectory: false)
        try Data("this is definitely not valid JSON".utf8).write(to: slotURL)

        do {
            _ = try await manager.load(slot: 0)
            Issue.record("expected decodeFailed to be thrown")
        } catch let error as SaveError {
            if case .decodeFailed = error {
                // expected
            } else {
                Issue.record("expected decodeFailed, got \(error)")
            }
        }
    }

    @Test func missingSlotYieldsFileNotFound() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = SaveManager(directoryURL: dir)

        do {
            _ = try await manager.load(slot: 42)
            Issue.record("expected fileNotFound")
        } catch let error as SaveError {
            #expect(error == SaveError.fileNotFound)
        }
    }
}
