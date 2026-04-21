#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// A horizontal HP bar whose fill is tinted by remaining HP percentage.
///
/// - green (> 50%)
/// - yellow (> 20%)
/// - red (otherwise)
///
/// The fill width is animated whenever `current` or `max` changes so callers
/// get free HP-drain animation by merely re-rendering with a new value.
struct HPBar: View {
    let current: Int
    let max: Int
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: geo.size.width * CGFloat(clampedFraction))
                    .animation(.easeOut(duration: 0.35), value: clampedFraction)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("HP \(Swift.max(current, 0)) of \(Swift.max(max, 0))")
    }

    private var clampedFraction: Double {
        guard max > 0 else { return 0 }
        let raw = Double(current) / Double(max)
        return Swift.max(0, Swift.min(1, raw))
    }

    private var fillColor: Color {
        if clampedFraction > 0.5 {
            return Color(red: 0.30, green: 0.80, blue: 0.35)
        }
        if clampedFraction > 0.2 {
            return Color(red: 0.95, green: 0.80, blue: 0.20)
        }
        return Color(red: 0.92, green: 0.30, blue: 0.30)
    }
}
#endif
