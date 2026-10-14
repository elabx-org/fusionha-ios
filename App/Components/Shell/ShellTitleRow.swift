import SwiftUI

/// The one header row every tab opens with (approved "App search redesign"):
/// the large title on the left, the page's own buttons, then the avatar on
/// the right, as in App Store and Music. It replaces the old top bar.
/// Tapping the current tab or the status bar scrolls to the top.
struct ShellTitleRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
                .pageTitle()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                trailing
                AvatarMenu()
            }
        }
    }
}

extension ShellTitleRow where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Keeps the status bar legible now that there is no top bar: a short fade
/// from the ground behind the clock and battery as content scrolls under.
struct StatusBarFade: View {
    var body: some View {
        Color.clear
            .frame(height: 1)
            .background(alignment: .top) {
                LinearGradient(stops: [.init(color: Theme.bg, location: 0),
                                       .init(color: Theme.bg.opacity(0.8), location: 0.6),
                                       .init(color: Theme.bg.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
