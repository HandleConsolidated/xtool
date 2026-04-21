#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Full-screen dialog renderer. Shows `lines[index]` in a text box; tap
/// anywhere to advance. The final tap dismisses the dialog back to the
/// overworld via `game.dismissDialog()`.
struct DialogView: View {
    let lines: [String]

    @EnvironmentObject var game: GameController
    @State private var index: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // A soft, non-opaque backdrop so the overworld feels paused
            // but still visible behind the dialog.
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer()
                dialogBox
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    private var dialogBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentLine)
                .font(.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("\(min(index + 1, max(lines.count, 1))) / \(max(lines.count, 1))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: isLast ? "checkmark.circle" : "chevron.right.circle")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
        )
    }

    private var currentLine: String {
        guard lines.indices.contains(index) else {
            return lines.last ?? ""
        }
        return lines[index]
    }

    private var isLast: Bool {
        index >= lines.count - 1
    }

    private func advance() {
        if isLast {
            game.dismissDialog()
        } else {
            index += 1
        }
    }
}
#endif
