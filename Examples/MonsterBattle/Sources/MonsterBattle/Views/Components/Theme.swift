#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Bridge between the Core's "(r,g,b) as Double" colour tuples and SwiftUI.
/// Kept as a dedicated initialiser so view code reads `Color(element.color)`
/// instead of spelling the components out each site.
extension Color {
    /// Build a SwiftUI `Color` from a 0...1 sRGB tuple. Values are clamped
    /// so a malformed input can't trip the runtime color system.
    init(_ rgb: (r: Double, g: Double, b: Double)) {
        let r = max(0, min(1, rgb.r))
        let g = max(0, min(1, rgb.g))
        let b = max(0, min(1, rgb.b))
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Small visual constants shared across the MonsterBattle UI. Mirrors the
/// dark-mode look we pin in `App.swift`.
enum Theme {
    static let panelBackground = Color.black.opacity(0.35)
    static let panelStroke = Color.white.opacity(0.12)
    static let cardCorner: CGFloat = 14
}
#endif
