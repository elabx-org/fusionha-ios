import SwiftUI

/// A row without a tile on a W1 card (mock `.group.noic` rows): the title
/// (and an optional second line), the value and a chevron when it opens
/// somewhere.
struct V2SettingsValueRow: View {
    let title: String
    var subtitle: String?
    var value: String?
    var chevron = true
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.dim)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A switch row on a W1 card (mock `K.row({ toggle })`).
struct V2SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    @Environment(\.pagePalette) private var page

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.indigo)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
    }
}

/// A footnote under a card (help text, "Only an admin can change this").
struct V2SettingsFootnote: View {
    let text: String
    var tone: Color?
    @Environment(\.pagePalette) private var page

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(tone ?? page?.inkMuted ?? Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
}
