#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Bridges the transient `GameController.pendingBattle` description to a
/// live `BattleController`, hosts `BattleView`, and hands results back
/// to the `GameController` when the fight ends.
///
/// We keep the `BattleController` on a small `@StateObject` host so its
/// lifetime is tied to the view, rather than the SwiftUI environment.
struct BattleScreenHost: View {
    @EnvironmentObject var game: GameController
    @StateObject private var host = Host()

    var body: some View {
        Group {
            if let controller = host.controller {
                BattleView(controller: controller)
                    // iOS 16 compatible single-parameter form.
                    .onChange(of: controller.state.outcome) { newOutcome in
                        guard newOutcome != .ongoing else { return }
                        handleBattleEnd(outcome: newOutcome, state: controller.state)
                    }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing battle...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            host.bind(to: game)
        }
    }

    /// Snapshot the pending kind before we clear the pending battle so
    /// trainer metadata (for `markNPCDefeated`) doesn't vanish.
    private func handleBattleEnd(outcome: BattleOutcome, state: BattleState) {
        let pendingKind = game.pendingBattle?.kind

        // Let the controller's own onAppear / render settle before mutating.
        Task { @MainActor in
            if case .trainer(let npcID, _, _, _) = pendingKind, outcome == .playerWon {
                game.markNPCDefeated(id: npcID)
            }
            game.onBattleEnded(outcome: outcome, finalState: state)
            game.clearPendingBattle()
        }
    }

    /// Keeps a single `BattleController` alive for the duration of one
    /// battle. Rebuilt from `GameController.pendingBattle` on first bind.
    @MainActor
    final class Host: ObservableObject {
        @Published var controller: BattleController?

        func bind(to game: GameController) {
            guard controller == nil, let pending = game.pendingBattle else { return }
            let playerParty = game.trainer.party.monsters
            guard !playerParty.isEmpty else { return }

            let leadIndex = playerParty.firstIndex(where: { !$0.isFainted }) ?? 0
            let playerSide = BattleSide.make(
                party: playerParty,
                activeIndex: leadIndex,
                isWild: false
            )

            let opponentSide: BattleSide
            let mode: BattleMode
            switch pending.kind {
            case .wild(let monster):
                opponentSide = BattleSide.make(party: [monster], activeIndex: 0, isWild: true)
                mode = .wild
            case .trainer(_, let classTitle, let name, let party):
                let active = party.firstIndex(where: { !$0.isFainted }) ?? 0
                opponentSide = BattleSide.make(
                    party: party,
                    activeIndex: active,
                    isWild: false
                )
                mode = .trainer(name: "\(classTitle) \(name)")
            }

            let state = BattleState(
                player: playerSide,
                opponent: opponentSide,
                mode: mode,
                seed: pending.seed
            )
            controller = BattleController(state: state)
        }
    }
}
#endif
