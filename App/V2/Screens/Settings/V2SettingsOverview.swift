import SwiftUI
import FusionhaKit

/// The open Duo's first Settings page (mock settings-v2.js `homeInner`):
/// "Overview", the server card, then the most used sections as cards in two
/// columns. The sidebar beside it reaches every panel.
struct V2SettingsOverview: View {
    let summary: V2SettingsSummary
    let select: (String) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @State private var width: CGFloat = 0

    private var leading: [V2SettingsNav.Section] {
        [.init(id: "general", header: "General", rows: SettingsNav.top), V2SettingsNav.home[1]]
    }

    private var trailing: [V2SettingsNav.Section] {
        V2SettingsNav.home.filter { $0.id == "fetching" || $0.id == "requests" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("The server, its health and what it holds.")
                    .font(.subheadline)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 10)
                V2SettingsServerCard(server: V2SettingsServer.name(model.client), summary: summary,
                                     storage: V2SettingsStorage(roots: summary.roots, library: model.library))
                if width >= 560 {
                    HStack(alignment: .top, spacing: 18) {
                        column(leading)
                        column(trailing)
                    }
                } else {
                    column(leading + trailing)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .navigationTitle("Overview")
        .toolbarTitleDisplayMode(.inlineLarge)
        .v2PageGround(art: nil)
    }

    private func column(_ sections: [V2SettingsNav.Section]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(sections) { section in
                V2SettingsSectionCard(section: section, summary: summary, open: select)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// Quality or Access on a phone (the home's group rows): its panels as one
/// card of hued rows, each pushed on top.
struct V2SettingsGroupPage: View {
    let id: String
    let summary: V2SettingsSummary
    @Environment(\.settingsPush) private var push

    var body: some View {
        ScrollView {
            V2SettingsSectionCard(section: .init(id: id, header: "", rows: V2SettingsNav.groups[id] ?? []),
                                  summary: summary, open: push)
                .padding(.horizontal, Theme.pageGutter)
                .padding(.bottom, 40)
        }
        .navigationTitle(V2SettingsNav.label(id))
        .toolbarTitleDisplayMode(.inlineLarge)
        .v2PageGround(art: nil)
    }
}
