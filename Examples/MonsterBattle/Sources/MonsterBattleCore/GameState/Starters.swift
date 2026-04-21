import Foundation

/// Content helper for handing the player a fresh level-5 starter.
public enum Starters {
    /// The three canonical starter species IDs.
    public static let choices: [String] = ["flarepup", "tidepaw", "sprigling"]

    /// Build a level-5 MonsterInstance for the given species using the
    /// supplied RNG for IV rolls. Delegates to `MonsterInstance.wild` so
    /// starters use the same moveset-selection logic as wild encounters.
    public static func monster(
        speciesID: String,
        rng: inout any RandomNumberGenerator
    ) -> MonsterInstance {
        let species = CreatureDex.species(speciesID)
        return MonsterInstance.wild(
            speciesID: speciesID,
            level: 5,
            species: species,
            moves: MoveDex.all,
            rng: &rng
        )
    }
}
