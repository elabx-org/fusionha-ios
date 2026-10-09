import SwiftUI
import FusionhaKit

/// One master-list row: 15pt icon, title (14.5/650) over a wrapping subtitle
/// (11.5 `--mut`), an optional ACTION tag and the trailing `›`.
struct SettingsMasterRow: View {
    let panel: SettingsPanelInfo

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: panel.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(panel.label)
                        .font(.system(size: 14.5, weight: .semibold))
                        .tracking(-0.145)
                        .foregroundStyle(Theme.txt)
                    Text(panel.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.mut)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 1)
                Spacer(minLength: 0)
                if panel.action { ActionTag() }
            }
            Text("›")
                .font(.system(size: 16))
                .foregroundStyle(Theme.dim)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The ACTION tag on Import Library.
private struct ActionTag: View {
    var body: some View {
        Text("ACTION")
            .font(.system(size: 8.5, weight: .heavy))
            .tracking(0.34)
            .foregroundStyle(Theme.cyan)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.cyan.opacity(0.4)))
            .padding(.top, 3)
    }
}

/// The `›` disclosure that turns 90° when its group opens (0.2s ease, instant
/// when motion is off).
struct SettingsChevron: View {
    let open: Bool
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        Text("›")
            .font(.system(size: 16))
            .foregroundStyle(Theme.mut)
            .rotationEffect(.degrees(open ? 90 : 0))
            .animation(motionOff ? nil : SettingsMotion.chevron, value: open)
    }
}

/// Rows have no resting fill; pressing tints them like the web's hover.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Ranked search results: SETTINGS (field hits) then PAGES.
struct SettingsSearchResults: View {
    let query: String
    let open: (SettingsSearchHit) -> Void

    var body: some View {
        let hits = SettingsSearchHit.search(query)
        let fields = hits.filter { $0.kind == .field }
        let pages = hits.filter { $0.kind == .page }
        VStack(alignment: .leading, spacing: 2) {
            if hits.isEmpty {
                Text("No settings match “\(query.trimmingCharacters(in: .whitespaces))”.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            if !fields.isEmpty { heading("Settings", fields.count) }
            ForEach(fields) { hit in resultRow(hit) }
            if !pages.isEmpty { heading("Pages", pages.count) }
            ForEach(pages) { hit in resultRow(hit) }
        }
    }

    private func heading(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title.uppercased())
            Spacer()
            Text("\(count)")
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.55)
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 3)
    }

    private func crumb(_ hit: SettingsSearchHit) -> AttributedString {
        var text = AttributedString(hit.crumb)
        if let keyword = hit.matchedKeyword {
            var match = AttributedString(" · matches “\(keyword)”")
            match.font = .system(size: 10.5, design: .monospaced)
            match.foregroundColor = Theme.cyan
            text += match
        }
        return text
    }

    private func resultRow(_ hit: SettingsSearchHit) -> some View {
        Button { open(hit) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                Text(crumb(hit))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}
