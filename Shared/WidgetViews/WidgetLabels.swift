import SwiftUI
import WidgetKit
import FusionhaKit

/// `TODAY`, `LATER`, `AWAITING APPROVAL`.
struct WidgetSectionLabel: View {
    let text: String
    var tint: Color = .secondary
    init(_ text: String, tint: Color = .secondary) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text.uppercased())
            .font(WidgetStyle.label)
            .tracking(0.5)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

/// A quiet centred line for an empty view (`Nothing airing soon`).
struct WidgetEmptyText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        WidgetStatusMessage(icon: nil, text: text)
    }
}

/// A centred state: an optional symbol, a line, and an optional detail.
struct WidgetStatusMessage: View {
    let icon: String?
    let text: String
    var detail: String?
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint)
                    .widgetAccentable()
                    .padding(.bottom, 2)
            }
            Text(text)
                .font(WidgetStyle.title)
                .foregroundStyle(icon == nil ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let detail {
                Text(detail)
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
