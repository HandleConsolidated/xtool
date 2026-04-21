import Foundation

/// A single equipped move with runtime PP state.
public struct MoveSlot: Codable, Sendable, Hashable {
    public var moveID: String
    public var currentPP: Int
    public var maxPP: Int

    public init(moveID: String, currentPP: Int, maxPP: Int) {
        self.moveID = moveID
        self.currentPP = currentPP
        self.maxPP = maxPP
    }

    /// Convenience initialiser that fills both PP values from a `Move`.
    public init(move: Move) {
        self.moveID = move.id
        self.currentPP = move.maxPP
        self.maxPP = move.maxPP
    }
}

/// A live monster owned by a trainer (wild or tame). Stats are derived
/// from the species base + level + IVs, not stored, so loading an
/// instance with a newer species definition just works.
public struct MonsterInstance: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var speciesID: String
    public var nickname: String?
    public var level: Int
    public var experience: Int
    public var currentHP: Int
    public var moves: [MoveSlot]
    public var status: StatusCondition
    /// 0...31 per stat. `hp` through `speed` are used; others are ignored
    /// but present to make serialisation symmetric with `Stats`.
    public var ivs: Stats

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        id: UUID = UUID(),
        speciesID: String,
        nickname: String? = nil,
        level: Int,
        experience: Int,
        currentHP: Int,
        moves: [MoveSlot],
        status: StatusCondition = .none,
        ivs: Stats
    ) {
        self.id = id
        self.speciesID = speciesID
        self.nickname = nickname
        self.level = level
        self.experience = experience
        self.currentHP = currentHP
        self.moves = moves
        self.status = status
        self.ivs = ivs
    }

    // MARK: - Derived stats

    /// Computes effective stats for this instance using the standard
    /// formula:
    ///   HP    = ((2*base + iv) * level / 100) + level + 10
    ///   other = ((2*base + iv) * level / 100) + 5
    public func stats(using species: CreatureSpecies) -> Stats {
        precondition(species.id == speciesID, "species mismatch")
        let lvl = max(1, level)
        func value(base: Int, iv: Int, isHP: Bool) -> Int {
            let clampedIV = max(0, min(31, iv))
            let raw = ((2 * base + clampedIV) * lvl) / 100
            return isHP ? raw + lvl + 10 : raw + 5
        }
        return Stats(
            hp: value(base: species.baseStats.hp, iv: ivs.hp, isHP: true),
            attack: value(base: species.baseStats.attack, iv: ivs.attack, isHP: false),
            defense: value(base: species.baseStats.defense, iv: ivs.defense, isHP: false),
            specialAttack: value(
                base: species.baseStats.specialAttack,
                iv: ivs.specialAttack,
                isHP: false
            ),
            specialDefense: value(
                base: species.baseStats.specialDefense,
                iv: ivs.specialDefense,
                isHP: false
            ),
            speed: value(base: species.baseStats.speed, iv: ivs.speed, isHP: false)
        )
    }

    public func maxHP(using species: CreatureSpecies) -> Int {
        stats(using: species).hp
    }

    public var isFainted: Bool { currentHP == 0 }

    public func displayName(using species: CreatureSpecies) -> String {
        nickname ?? species.name
    }

    // MARK: - Factories

    /// Build a wild encounter. Picks the 4 most recent level-appropriate
    /// moves from the species learnset and assigns random 0...31 IVs.
    public static func wild(
        speciesID: String,
        level: Int,
        species: CreatureSpecies,
        moves: [Move],
        rng: inout any RandomNumberGenerator
    ) -> MonsterInstance {
        precondition(species.id == speciesID, "species mismatch")
        let lvl = max(1, level)

        // Learnset entries the monster is high enough to have, newest first.
        let eligible = species.learnset
            .filter { $0.level <= lvl }
            .sorted { $0.level > $1.level }

        var slots: [MoveSlot] = []
        for entry in eligible {
            if slots.count >= 4 { break }
            guard slots.allSatisfy({ $0.moveID != entry.moveID }),
                  let move = moves.first(where: { $0.id == entry.moveID })
            else { continue }
            slots.append(MoveSlot(move: move))
        }
        // Guarantee at least one move: fall back to the first learnset entry.
        if slots.isEmpty, let first = species.learnset.first,
           let move = moves.first(where: { $0.id == first.moveID }) {
            slots.append(MoveSlot(move: move))
        }

        // Roll each IV sequentially; we can't capture an inout rng in a
        // nested func/closure under strict concurrency, so inline it.
        let ivHP = randomInt(in: 0...31, using: &rng)
        let ivAtk = randomInt(in: 0...31, using: &rng)
        let ivDef = randomInt(in: 0...31, using: &rng)
        let ivSpA = randomInt(in: 0...31, using: &rng)
        let ivSpD = randomInt(in: 0...31, using: &rng)
        let ivSpe = randomInt(in: 0...31, using: &rng)
        let ivs = Stats(
            hp: ivHP,
            attack: ivAtk,
            defense: ivDef,
            specialAttack: ivSpA,
            specialDefense: ivSpD,
            speed: ivSpe
        )

        let xp = species.growthRate.experienceToReach(level: lvl)
        var instance = MonsterInstance(
            speciesID: speciesID,
            level: lvl,
            experience: xp,
            currentHP: 1,
            moves: slots,
            ivs: ivs
        )
        instance.currentHP = instance.maxHP(using: species)
        return instance
    }
}
