#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// A stand-in "sprite" for a creature: the species emoji inside a soft
/// circle tinted by the creature's primary type.
///
/// Kept deliberately simple — the feature is emoji-only art, no images.
struct CreatureSprite: View {
    let species: CreatureSpecies
    var facing: Direction = .south
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(species.primaryType.color).opacity(0.70),
                            Color(species.primaryType.color).opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .stroke(Color(species.primaryType.color).opacity(0.85), lineWidth: 2)
            Text(species.emoji)
                .font(.system(size: size * 0.55))
                .scaleEffect(x: facing == .west ? -1 : 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(species.name) (\(species.primaryType.displayName))")
    }
}
#endif
