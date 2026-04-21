#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Title screen: fancy gradient backdrop + New Game / Continue buttons.
///
/// The gradient uses every element's suggested colour so the intro feels
/// like "the world of Monster Battle" before any single type is revealed.
struct MainMenuView: View {
    @EnvironmentObject var game: GameController

    @State private var showingNewGameSheet: Bool = false
    @State private var continueAvailable: Bool = false

    var body: some View {
        ZStack {
            gradient
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Monster Battle")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                    Text("An adventure awaits!")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showingNewGameSheet = true
                    } label: {
                        menuLabel("New Game", system: "sparkles")
                    }
                    .buttonStyle(.plain)

                    Button {
                        game.loadSave()
                    } label: {
                        menuLabel("Continue", system: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(!continueAvailable)
                    .opacity(continueAvailable ? 1 : 0.4)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .task(id: game.scene) {
            await refreshContinueAvailability()
        }
        .sheet(isPresented: $showingNewGameSheet) {
            NewGameSheet { name, starterID in
                showingNewGameSheet = false
                game.newGame(trainerName: name, starterSpeciesID: starterID)
            } cancel: {
                showingNewGameSheet = false
            }
        }
    }

    private func menuLabel(_ text: String, system: String) -> some View {
        HStack {
            Image(systemName: system)
            Text(text).font(.title3.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: Element.allCases.map { Color($0.color) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// SaveManager is an actor, so checking whether slot 0 exists is async.
    /// We cache the result in local state and refresh it whenever the scene
    /// revisits the main menu (e.g. after "Return to Main Menu").
    private func refreshContinueAvailability() async {
        guard let manager = game.saveManager else {
            continueAvailable = false
            return
        }
        let exists = await manager.slotExists(slot: 0)
        await MainActor.run {
            self.continueAvailable = exists
        }
    }
}

/// Modal sheet that collects the trainer name and a starter pick for a
/// fresh game. Three starter buttons tinted by each starter's type.
private struct NewGameSheet: View {
    var onStart: (_ name: String, _ starterID: String) -> Void
    var cancel: () -> Void

    @State private var trainerName: String = ""

    private struct StarterChoice {
        let speciesID: String
        let displayName: String
        let emoji: String
    }

    private let choices: [StarterChoice] = [
        StarterChoice(speciesID: "flarepup",  displayName: "Flarepup",  emoji: "\u{1F98A}"),
        StarterChoice(speciesID: "tidepaw",   displayName: "Tidepaw",   emoji: "\u{1F9A6}"),
        StarterChoice(speciesID: "sprigling", displayName: "Sprigling", emoji: "\u{1F331}")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose your trainer name")
                        .font(.headline)
                    TextField("Trainer name", text: $trainerName)
                        .textFieldStyle(.roundedBorder)

                    Text("Pick your starter")
                        .font(.headline)

                    ForEach(choices, id: \.speciesID) { choice in
                        Button {
                            let trimmed = trainerName.trimmingCharacters(in: .whitespaces)
                            let name = trimmed.isEmpty ? "Trainer" : trimmed
                            onStart(name, choice.speciesID)
                        } label: {
                            starterRow(for: choice)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
    }

    @ViewBuilder
    private func starterRow(for choice: StarterChoice) -> some View {
        let species = CreatureDex.byID[choice.speciesID]
        HStack(spacing: 14) {
            Text(choice.emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.displayName).font(.title3.weight(.bold))
                if let species {
                    Text(species.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        ForEach(species.types, id: \.self) { t in
                            TypeBadge(element: t, compact: true)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color((species?.primaryType ?? .flame).color).opacity(0.6),
                    lineWidth: 2
                )
        )
    }
}
#endif
