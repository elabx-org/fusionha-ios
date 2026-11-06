import SwiftUI

/// One S1 row (mock `trow`): the hued tile, the title (with an optional
/// second line), the trailing value or the ACTION tag, and the chevron.
struct V2SettingsRow: View {
    let id: String
    var subtitle: String?
    var value: String?
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 13) {
            V2SettingsTile(id: id)
            VStack(alignment: .leading, spacing: 1) {
                Text(V2SettingsNav.label(id))
                    .font(.body)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if SettingsNav.panel(id)?.action == true {
                V2SettingsActionTag()
            } else if let value {
                Text(value)
                    .font(.callout)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle == nil ? 48 : 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The ACTION tag on Import Library (an action, not a setting).
struct V2SettingsActionTag: View {
    var body: some View {
        Text("ACTION")
            .font(.caption2.weight(.heavy))
            .tracking(0.4)
            .foregroundStyle(Theme.accentText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.indigo.opacity(0.16), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A section: its header (or a gap) and its rows on one W1 card, rows split
/// by hairlines inset past the tile (iOS grouped style).
struct V2SettingsSectionCard: View {
    let section: V2SettingsNav.Section
    let summary: V2SettingsSummary
    let open: (String) -> Void
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if section.header.isEmpty {
                Color.clear.frame(height: 6)
            } else {
                Text(section.header)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.element) { index, id in
                    Button { open(id) } label: {
                        V2SettingsRow(id: id, subtitle: subtitle(id), value: summary.value(id))
                    }
                    .buttonStyle(V2SettingsPressStyle())
                    .overlay(alignment: .top) {
                        if index > 0 {
                            ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight)
                                .frame(height: EditionChip.hairline(displayScale))
                                .padding(.leading, 59)
                        }
                    }
                }
            }
            // Clip the press tint to the card, not the card's shadow.
            .clipShape(RoundedRectangle(cornerRadius: ModuleMetrics.radius, style: .continuous))
            .background { ModuleSurface() }
        }
    }

    private func subtitle(_ id: String) -> String? {
        V2SettingsNav.subtitles[id] ?? V2SettingsNav.groupSubtitles[id]
    }
}

/// Rows have no resting fill; a press tints them like a system list.
struct V2SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.08 : 0))
    }
}
