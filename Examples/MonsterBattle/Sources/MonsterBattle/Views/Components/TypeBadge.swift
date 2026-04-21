#if canImport(SwiftUI)
import SwiftUI
import MonsterBattleCore

/// Small coloured pill showing an element type with its emoji + name.
/// Used in the party / move panels.
struct TypeBadge: View {
    let element: Element
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(element.emoji)
            if !compact {
                Text(element.displayName)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(Color(element.color).opacity(0.85))
        )
        .foregroundStyle(Color.black.opacity(0.85))
    }
}

/// Compact pill for a status condition (PSN / BRN / …) tinted per-status.
struct StatusChip: View {
    let status: StatusCondition

    var body: some View {
        Group {
            if status == .none {
                EmptyView()
            } else {
                Text(status.abbreviation)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(status.color).opacity(0.85))
                    )
                    .foregroundStyle(Color.black.opacity(0.85))
            }
        }
    }
}
#endif
