import SwiftUI
import FusionhaKit

/// The S1 Settings home on a phone and the folded Duo (mock settings-v2.js
/// `homeBody`): the server card, then grouped cards of hued rows. Quality
/// and Access open their own lists. Search results replace the cards
/// while a query is typed.
struct V2SettingsHome: View {
    let summary: V2SettingsSummary
    let query: String
    let open: (String) -> Void
    let openHit: (SettingsSearchHit) -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                V2SettingsServerCard(server: V2SettingsServer.name(model.client), summary: summary,
                                     storage: V2SettingsStorage(roots: summary.roots, library: model.library))
                    .padding(.bottom, 4)
                ForEach(V2SettingsNav.home) { section in
                    V2SettingsSectionCard(section: section, summary: summary, open: open)
                }
            } else {
                SettingsSearchResults(query: query, open: openHit)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .v2CardStyle(padding: 0)
            }
        }
        .padding(.horizontal, Theme.pageGutter)
    }
}

/// The server's name as the card shows it: host, and the port when there is one.
enum V2SettingsServer {
    static func name(_ client: APIClient?) -> String {
        guard let url = client?.baseURL, let host = url.host() else { return "fusionha" }
        return url.port.map { "\(host):\($0)" } ?? host
    }
}

/// The open Duo's sidebar (mock `side`): every panel as a compact hued row
/// under its section, the open one marked.
struct V2SettingsSidebar: View {
    let selected: String?
    let summary: V2SettingsSummary
    let select: (String) -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(V2SettingsNav.sidebar) { section in
                if !section.header.isEmpty {
                    Text(section.header.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .padding(.horizontal, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(section.rows, id: \.self) { id in row(id) }
            }
        }
        .padding(.horizontal, 12)
    }

    private func row(_ id: String) -> some View {
        let on = selected == id
        return Button { select(id) } label: {
            HStack(spacing: 11) {
                V2SettingsTile(id: id, size: 26)
                Text(V2SettingsNav.label(id))
                    .font(.subheadline.weight(on ? .semibold : .regular))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if SettingsNav.panel(id)?.action == true {
                    V2SettingsActionTag()
                } else if let value = summary.value(id) {
                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 40)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((page?.ink ?? Theme.txt).opacity(0.11))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
