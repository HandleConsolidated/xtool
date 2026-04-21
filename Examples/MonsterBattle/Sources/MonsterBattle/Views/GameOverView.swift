#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// End-of-run screen shown when the trainer's entire party faints.
/// One big headline and a single button back to the title screen.
struct GameOverView: View {
    @EnvironmentObject var game: GameController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.02, blue: 0.10),
                    Color(red: 0.25, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Text("You blacked out")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
                    .multilineTextAlignment(.center)
                Text("Your adventure ends here — for now.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    game.present(scene: .mainMenu)
                } label: {
                    Text("Back to Menu")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding()
        }
    }
}
#endif
