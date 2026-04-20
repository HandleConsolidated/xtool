import Foundation

/// One of six elemental affinities used by both creatures and moves.
///
/// Type chart (attacker row x defender column):
/// ```
///          flame   aqua   leaf   spark  stone  gust
///  flame    0.5    0.5    2.0    1.0    0.5    1.0
///  aqua     2.0    0.5    1.0    0.5    1.0    1.0
///  leaf     0.5    2.0    0.5    1.0    2.0    0.5
///  spark    1.0    2.0    1.0    0.5    0.5    2.0
///  stone    2.0    1.0    0.5    2.0    0.5    2.0
///  gust     1.0    1.0    2.0    0.5    1.0    0.5
/// ```
///
/// Cycles (2x damage):
/// - flame > leaf > spark > aqua > flame
/// - stone > gust > spark (gust also beats spark)
/// - stone > flame (hard rock resists fire in this setting's flavour)
/// - leaf > stone, gust > stone? The chart above enforces stone > gust,
///   and gust is weak vs leaf (wind dispersed by the canopy).
///
/// Same-type hits are 0.5 (resist). Unlisted matchups default to 1.0.
public enum Element: String, CaseIterable, Codable, Sendable, Hashable {
    case flame, aqua, leaf, spark, stone, gust

    /// Effectiveness multiplier when an attacker of this type hits `defender`.
    public func effectiveness(against defender: Element) -> Double {
        switch (self, defender) {
        // Same element -> resist
        case (.flame, .flame), (.aqua, .aqua), (.leaf, .leaf),
             (.spark, .spark), (.stone, .stone), (.gust, .gust):
            return 0.5

        // flame: burns leaves, but water douses it and stones smother it
        case (.flame, .leaf): return 2.0
        case (.flame, .aqua): return 0.5
        case (.flame, .stone): return 0.5

        // aqua: extinguishes flame, but sparks electrify water, leaf drinks it
        case (.aqua, .flame): return 2.0
        case (.aqua, .spark): return 0.5
        case (.aqua, .leaf): return 1.0

        // leaf: roots crack stone and soak water, but fire burns it; spark neutral
        case (.leaf, .aqua): return 2.0
        case (.leaf, .stone): return 2.0
        case (.leaf, .flame): return 0.5
        case (.leaf, .gust): return 0.5

        // spark: zaps water and rides wind, fizzles on stone (grounded)
        case (.spark, .aqua): return 2.0
        case (.spark, .gust): return 2.0
        case (.spark, .stone): return 0.5

        // stone: crushes flame, spark (grounds it), wind (heavy), weak to leaf
        case (.stone, .flame): return 2.0
        case (.stone, .spark): return 2.0
        case (.stone, .gust): return 2.0
        case (.stone, .leaf): return 0.5

        // gust: disperses leaf? No - leaves shield; wind cuts spark off ground?
        // In this chart: gust strong vs leaf (shreds foliage), weak vs stone/spark
        case (.gust, .leaf): return 2.0
        case (.gust, .spark): return 0.5
        case (.gust, .stone): return 1.0

        default:
            return 1.0
        }
    }

    /// Human-readable, capitalised name.
    public var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Emoji stand-in so the UI can render types without sprites.
    public var emoji: String {
        switch self {
        case .flame: return "\u{1F525}"   // fire
        case .aqua:  return "\u{1F4A7}"   // droplet
        case .leaf:  return "\u{1F33F}"   // herb
        case .spark: return "\u{26A1}"    // high voltage
        case .stone: return "\u{1FAA8}"   // rock
        case .gust:  return "\u{1F300}"   // cyclone
        }
    }

    /// Suggested tint colour in 0...1 sRGB space.
    public var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .flame: return (0.94, 0.35, 0.15)
        case .aqua:  return (0.20, 0.55, 0.95)
        case .leaf:  return (0.30, 0.75, 0.35)
        case .spark: return (0.98, 0.85, 0.20)
        case .stone: return (0.60, 0.50, 0.35)
        case .gust:  return (0.70, 0.85, 0.95)
        }
    }
}
