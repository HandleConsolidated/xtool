import Foundation

/// Outcome of a battle. The engine advances through `.ongoing` until
/// one of the terminal cases is reached.
public enum BattleOutcome: String, Sendable, Codable, Equatable {
    case ongoing
    case playerWon
    case playerLost
    case fled
    case caught
}

/// Coarse type-effectiveness bucket for the UI. Derived from a raw
/// multiplier via `init(multiplier:)`.
public enum Effectiveness: Sendable, Equatable {
    case superEffective
    case neutral
    case notVeryEffective
    case noEffect

    /// Classify a raw effectiveness multiplier.
    public init(multiplier: Double) {
        if multiplier <= 0 {
            self = .noEffect
        } else if multiplier > 1.0 {
            self = .superEffective
        } else if multiplier < 1.0 {
            self = .notVeryEffective
        } else {
            self = .neutral
        }
    }
}

/// Why a combatant could not act on a given turn.
public enum SkipReason: Sendable, Equatable {
    case paralyzed
    case asleep(turnsLeft: Int)
    case frozen
}

/// A structured, UI-friendly record of a single battle event.
///
/// The engine emits these in order; animating them back in the UI
/// reproduces the fight without any string parsing.
public enum BattleEvent: Sendable, Equatable {
    case turnStart(number: Int)
    case message(String)
    case moveUsed(attackerID: UUID, move: String)
    case moveMissed(attackerID: UUID)
    case damageDealt(defenderID: UUID, amount: Int, effectiveness: Effectiveness, critical: Bool)
    case healed(monsterID: UUID, amount: Int)
    case statChanged(monsterID: UUID, stat: StatKind, delta: Int)
    case statusApplied(monsterID: UUID, status: StatusCondition)
    case statusCured(monsterID: UUID, status: StatusCondition)
    case statusDamage(monsterID: UUID, status: StatusCondition, amount: Int)
    case skippedTurn(monsterID: UUID, reason: SkipReason)
    case fainted(monsterID: UUID)
    case caughtCreature(speciesID: String)
    case captureFailed(shakes: Int)
    case ran(successful: Bool)
    case experienceGained(monsterID: UUID, amount: Int)
    case leveledUp(monsterID: UUID, newLevel: Int)
    case learnedMove(monsterID: UUID, moveID: String)
    case evolved(fromSpeciesID: String, toSpeciesID: String, monsterID: UUID)
    case battleEnded(outcome: BattleOutcome)
}
