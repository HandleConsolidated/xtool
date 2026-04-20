import Foundation

/// Persistent status effects that can afflict a monster in battle.
public enum StatusCondition: String, Codable, Sendable, CaseIterable, Hashable {
    case none, poison, burn, paralyze, sleep, freeze

    /// Fraction of max HP lost at end of each turn from this status.
    /// 0 means no residual damage.
    public var damageFraction: Double {
        switch self {
        case .poison: return 1.0 / 8.0
        case .burn:   return 1.0 / 16.0
        default:      return 0.0
        }
    }

    /// Physical attack multiplier (burn halves attack).
    public var attackMultiplier: Double {
        self == .burn ? 0.5 : 1.0
    }

    /// Speed multiplier (paralysis halves speed).
    public var speedMultiplier: Double {
        self == .paralyze ? 0.5 : 1.0
    }

    /// Probability (0...1) that the monster fails to act this turn.
    /// Sleep/freeze are handled with duration logic elsewhere; this is the
    /// raw "rolled before acting" chance for the basic case.
    public var skipTurnProbability: Double {
        switch self {
        case .paralyze: return 0.25
        case .freeze:   return 1.0
        case .sleep:    return 1.0
        default:        return 0.0
        }
    }

    /// Probability per turn that a freeze thaws on its own (20%).
    public var thawProbability: Double {
        self == .freeze ? 0.20 : 0.0
    }

    /// Returns the length of a new sleep, in turns, as (min, max).
    public var sleepTurnRange: ClosedRange<Int> {
        self == .sleep ? 1...3 : 0...0
    }

    public var displayName: String {
        switch self {
        case .none:     return "Healthy"
        case .poison:   return "Poisoned"
        case .burn:     return "Burned"
        case .paralyze: return "Paralyzed"
        case .sleep:    return "Asleep"
        case .freeze:   return "Frozen"
        }
    }

    /// Short badge label used next to a creature's HP bar.
    public var abbreviation: String {
        switch self {
        case .none:     return ""
        case .poison:   return "PSN"
        case .burn:     return "BRN"
        case .paralyze: return "PAR"
        case .sleep:    return "SLP"
        case .freeze:   return "FRZ"
        }
    }

    /// UI tint colour for the status chip (0...1 sRGB).
    public var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .none:     return (0.60, 0.60, 0.60)
        case .poison:   return (0.65, 0.30, 0.80)
        case .burn:     return (0.95, 0.35, 0.15)
        case .paralyze: return (0.95, 0.85, 0.20)
        case .sleep:    return (0.45, 0.40, 0.65)
        case .freeze:   return (0.55, 0.85, 0.95)
        }
    }
}
