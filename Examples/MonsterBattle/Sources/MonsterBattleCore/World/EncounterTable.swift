import Foundation

/// A table of possible wild encounters for a single tall-grass patch
/// (currently shared across every `.tallGrass` tile on a map).
public struct EncounterTable: Codable, Sendable, Hashable {
    /// One wild-encounter option with its weight and level band.
    public struct Entry: Codable, Sendable, Hashable {
        public var speciesID: String
        public var minLevel: Int
        public var maxLevel: Int
        public var weight: Int

        public init(speciesID: String, minLevel: Int, maxLevel: Int, weight: Int) {
            self.speciesID = speciesID
            self.minLevel = minLevel
            self.maxLevel = maxLevel
            self.weight = weight
        }
    }

    public var entries: [Entry]
    /// Percentage chance (0...100) that a step into tall grass triggers
    /// an encounter at all. Independent of the per-entry weights.
    public var encounterChance: Int

    public init(entries: [Entry], encounterChance: Int = 10) {
        self.entries = entries
        self.encounterChance = encounterChance
    }

    /// Attempt to generate a wild encounter for a single tall-grass step.
    /// Returns nil when `encounterChance` fails its roll or when the
    /// table is empty / all weights are non-positive.
    public func roll(rng: inout any RandomNumberGenerator) -> MonsterInstance? {
        guard !entries.isEmpty else { return nil }
        let clampedChance = max(0, min(100, encounterChance))
        guard clampedChance > 0 else { return nil }

        let triggerRoll = randomInt(below: 100, using: &rng)
        guard triggerRoll < clampedChance else { return nil }

        let weighted: [(Entry, Int)] = entries.map { ($0, $0.weight) }
        guard let entry = weightedRandom(weighted, using: &rng) else { return nil }

        let lo = min(entry.minLevel, entry.maxLevel)
        let hi = max(entry.minLevel, entry.maxLevel)
        let level = randomInt(in: lo...hi, using: &rng)

        let species = CreatureDex.species(entry.speciesID)
        let learnsetIDs = Set(species.learnset.map { $0.moveID })
        let moves = MoveDex.all.filter { learnsetIDs.contains($0.id) }

        return MonsterInstance.wild(
            speciesID: entry.speciesID,
            level: level,
            species: species,
            moves: moves,
            rng: &rng
        )
    }
}
