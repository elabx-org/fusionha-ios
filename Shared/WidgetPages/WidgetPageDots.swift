import SwiftUI
import WidgetKit
import FusionhaKit

/// One dot per view, the current one wide and bright. The whole control is a
/// single button that flicks to the next view (a dot alone is too small to hit),
/// on a capsule so it reads as a control rather than content.
struct WidgetPageDots: View {
    let pages: [WidgetPage]
    let current: WidgetPage
    let familyKey: String

    var body: some View {
        let next = WidgetPage.next(after: current, in: pages)
        Button(intent: SetWidgetPageIntent(family: familyKey, page: next)) {
            HStack(spacing: 4) {
                ForEach(pages, id: \.self) { page in
                    Capsule()
                        .fill(page == current ? Color.primary : Color.secondary.opacity(0.45))
                        .frame(width: page == current ? 12 : 5, height: 5)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \((pages.firstIndex(of: current) ?? 0) + 1) of \(pages.count), \(current.title)")
        .accessibilityHint("Shows \(next.title)")
    }
}
