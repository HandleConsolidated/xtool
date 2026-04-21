import Foundation
import Testing
@testable import MonsterBattleCore

@Suite("BattleState end-to-end")
struct BattleStateTests {

    // MARK: - Helpers

    private func makePlayerMonster(
        speciesID: String,
        level: Int,
        seed: UInt64
    ) -> MonsterInstance {
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

    private func makeBattle(
        playerSpecies: String,
        playerLevel: Int,
        opponentSpecies: String,
        opponentLevel: Int,
        seed: UInt64
    ) -> BattleState {
        let player = makePlayerMonster(speciesID: playerSpecies, level: playerLevel, seed: seed)
        let opponent = makePlayerMonster(speciesID: opponentSpecies, level: opponentLevel, seed: seed &+ 1)
        let playerSide = BattleSide.make(party: [player], isWild: false)
        let opponentSide = BattleSide.make(party: [opponent], isWild: true)
        return BattleState(
            player: playerSide,
            opponent: opponentSide,
            mode: .wild,
            seed: seed
        )
    }

    /// Runs a battle until it terminates, submitting slot-0 fights. Aborts
    /// after `turnCap` turns to avoid a hang if something is very wrong.
    private func runUntilTerminal(
        _ state: inout BattleState,
        turnCap: Int = 100
    ) {
        var iterations = 0
        while state.outcome == .ongoing && iterations < turnCap {
            _ = state.submit(playerAction: .fight(moveSlotIndex: 0))
            iterations += 1
            // Handle forced switches (our party only has one mon, so this
            // routes to a player-lost outcome).
            if state.awaitingPlayerSwitch {
                _ = state.submit(playerAction: .fight(moveSlotIndex: 0))
            }
        }
    }

    // MARK: - Tests

    @Test func seedSweepUsuallyProducesATerminalOutcome() {
        // Voltkit L5 vs wild Boulderling L3. Under the real damage curves
        // this matchup can go either way; the important invariant is that
        // the engine terminates across seeds and most battles produce a
        // decisive outcome (not a stall).
        var terminalCount = 0
        var playerWinCount = 0
        let seeds: [UInt64] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        for seed in seeds {
            var state = makeBattle(
                playerSpecies: "voltkit",
                playerLevel: 5,
                opponentSpecies: "boulderling",
                opponentLevel: 3,
                seed: seed
            )
            runUntilTerminal(&state)
            if state.outcome != .ongoing { terminalCount += 1 }
            if state.outcome == .playerWon { playerWinCount += 1 }
        }
        #expect(terminalCount == seeds.count)
        // We don't assert a strict win rate here because Voltkit's L5
        // moveset versus Boulderling's stone-typed bulk is a real coin-flip.
        // The sanity invariant we care about is "the battle actually ends".
    }

    @Test func higherLevelPlayerReliablyWins() {
        // A severely-favoured matchup: voltkit L20 shreds a boulderling L3.
        // Across a seed sweep we expect >90% player wins.
        var wins = 0
        let seeds: [UInt64] = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
        for seed in seeds {
            var state = makeBattle(
                playerSpecies: "voltkit",
                playerLevel: 20,
                opponentSpecies: "boulderling",
                opponentLevel: 3,
                seed: seed
            )
            runUntilTerminal(&state)
            if state.outcome == .playerWon { wins += 1 }
        }
        #expect(wins >= 9)
    }

    @Test func runActionSometimesSucceedsAcrossSeeds() {
        // 20 seeds, at least one should flee (~50% success rate).
        var flees = 0
        for seed in UInt64(100)..<UInt64(120) {
            var state = makeBattle(
                playerSpecies: "voltkit",
                playerLevel: 10,
                opponentSpecies: "boulderling",
                opponentLevel: 3,
                seed: seed
            )
            _ = state.submit(playerAction: .run)
            if state.outcome == .fled { flees += 1 }
        }
        #expect(flees >= 1)
    }

    @Test func submittingAfterTerminalOutcomeReturnsEmpty() {
        var state = makeBattle(
            playerSpecies: "voltkit",
            playerLevel: 20,
            opponentSpecies: "boulderling",
            opponentLevel: 2,
            seed: 54321
        )
        runUntilTerminal(&state)
        #expect(state.outcome != .ongoing)
        let snapshotTurn = state.turn
        let snapshotLogSize = state.log.count
        let events = state.submit(playerAction: .fight(moveSlotIndex: 0))
        #expect(events.isEmpty)
        #expect(state.turn == snapshotTurn)
        #expect(state.log.count == snapshotLogSize)
    }

    @Test func faintingPlayerOnlyMonsterSetsPlayerLost() {
        // Level-1 voltkit with 1 HP vs a level-50 thunderock: boulderling
        // with 1 HP can't survive a hit. The player has exactly one party
        // member, so the forced-switch fallback routes to .playerLost.
        var weakPlayer = makePlayerMonster(speciesID: "voltkit", level: 1, seed: 1)
        weakPlayer.currentHP = 1
        let strongOpponent = makePlayerMonster(speciesID: "thunderock", level: 50, seed: 2)
        let playerSide = BattleSide.make(party: [weakPlayer], isWild: false)
        let opponentSide = BattleSide.make(party: [strongOpponent], isWild: true)
        var state = BattleState(
            player: playerSide,
            opponent: opponentSide,
            mode: .wild,
            seed: 0xC0FFEE
        )
        runUntilTerminal(&state, turnCap: 20)
        #expect(state.outcome == .playerLost)
    }
}
