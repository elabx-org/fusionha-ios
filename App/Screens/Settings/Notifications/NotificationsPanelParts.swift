import SwiftUI
import FusionhaKit

// Settings › Notifications layout pieces (web `NotificationsPanel.module.css`
// and `notifications-a10.module.css`): the section heading, the card, a
// name + description row, the 7pt severity dot and the New/Retired pills.

/// The uppercase section heading with a trailing hairline (web `Sec`).
struct NotifSec: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
                .fixedSize()
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.top, 20)
        .padding(.bottom, 9)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The solid rounded card the rows sit on (`.card`).
struct NotifCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
    }
}

/// A name and description on the left, a control on the right (`.row`).
struct NotifRow<Trailing: View>: View {
    let name: String
    let desc: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            FieldLabel(label: name, description: desc)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 8)
    }
}

/// The event kind's 7pt category dot (`.sev`); replaces the old 3×30 bar.
/// Under Monochrome every kind reads as the same quiet shade.
struct NotifSeverityDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(Theme.isMono ? Theme.mut : color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}

/// The small uppercase "New" / "Retired" pill (`.newp` / `.retp`).
struct NotifKindPill: View {
    enum Kind { case new, retired }
    let kind: Kind

    var body: some View {
        Text(kind == .new ? "NEW" : "RETIRED")
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(kind == .new ? Theme.onTint(Theme.grab) : Theme.mut)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(kind == .new ? Theme.grab : Theme.panel2,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .fixedSize()
            .accessibilityLabel(kind == .new ? "New" : "Retired")
    }
}
