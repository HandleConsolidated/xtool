#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Root of the app's scene graph. Switches on `GameController.scene` to
/// pick the current top-level screen, and overlays a transient save/load
/// error toast when `game.saveError` is non-nil.
struct RootView: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
                .transition(.opacity)

            if let err = game.saveError {
                VStack {
                    ErrorToast(text: err)
                        .padding(.top, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.scene)
        .animation(.easeInOut(duration: 0.2), value: game.saveError)
    }

    @ViewBuilder
    private var content: some View {
        switch game.scene {
        case .mainMenu:
            MainMenuView()
        case .overworld:
            OverworldView()
        case .battle:
            BattleScreenHost()
        case .party:
            PartyView()
        case .bag:
            BagView()
        case .dialog(let lines):
            DialogView(lines: lines)
        case .gameOver:
            GameOverView()
        }
    }
}

/// Transient banner that surfaces a save / load error. Auto-dismisses
/// after three seconds via a small `@State` timer.
struct ErrorToast: View {
    var text: String

    @EnvironmentObject private var game: GameController
    @State private var visible: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.25, green: 0.08, blue: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .padding(.horizontal, 20)
        .opacity(visible ? 1 : 0)
        .task(id: text) {
            visible = true
            // Give the user ~3s to read the message, then fade.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
                visible = false
            }
        }
    }
}
#endif
