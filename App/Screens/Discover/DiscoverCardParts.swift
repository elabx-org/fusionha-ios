import SwiftUI
import FusionhaKit

/// A card's meta-line chip: Requested, Approved, Watching (a wash, no border).
struct DiscoverCardChip: View {
    let text: String
    var systemImage: String?
    let ink: Color
    let wash: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(ink)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(wash, in: Capsule())
        .lineLimit(1)
        .fixedSize()
    }
}

/// The persistent corner ＋ on an addable card (web `.addBtn` on coarse
/// pointers): the accent disc, a 44pt target, the Add sheet on tap.
struct DiscoverQuickAdd: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 30, height: 30)
                .background(Theme.primary, in: Circle())
                .shadow(color: Theme.shelfShadow.opacity(0.5), radius: 6, y: 3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel("Add \(title)")
    }
}
