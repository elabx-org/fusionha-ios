import SwiftUI
import FusionhaKit

/// "Import as" (the web's `ImportAsFields`): every editable value once, one
/// tap each. A change goes straight to the server and the row re-evaluates.
struct MIImportAsFields: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable { case episodes, languages; var id: String { rawValue } }

    private var matched: Bool { row.match.itemId != nil }
    private var series: Bool { row.target.isSeries }

    var body: some View {
        VStack(spacing: 0) {
            if matched && series {
                field(row.target.coveredEpisodeIds.count > 1 ? "Episodes" : "Episode", episodeValue) { sheet = .episodes }
            }
            if matched && !series { editionMenu }
            if matched { versionMenu }
            qualityMenu
            if matched {
                field("Languages", (row.languages ?? []).isEmpty ? "Unknown" : (row.languages ?? []).joined(separator: ", ")) {
                    sheet = .languages
                }
            }
            if matched && series { releaseMenu }
        }
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .disabled(row.committed || session.pendingRows.contains(row.rowId))
        .sheet(item: $sheet) { which in
            switch which {
            case .episodes: MIEpisodeSheet(row: row)
            case .languages: MILanguagesSheet(row: row)
            }
        }
    }

    private func set(_ fields: [String: SettingsJSON]) {
        Task { await session.patch(row, fields) }
    }

    private var episodeValue: String {
        let code = ManualImportRules.episodeCode(row)
        guard let item = row.match.itemId, let seasons = session.seasons[item] else { return code ?? "—" }
        let ids = Set(row.target.coveredEpisodeIds)
        let titles = seasons.flatMap(\.episodes).filter { ids.contains($0.id) }.compactMap(\.title)
        return ([code].compactMap { $0 } + [titles.joined(separator: " + ")].filter { !$0.isEmpty }).joined(separator: " · ")
    }

    private var editionMenu: some View {
        Menu {
            Button("Standard") { set(["edition": nil]) }
            ForEach(session.editionNames.filter { $0 != "Standard" }, id: \.self) { name in
                Button(name) { set(["edition": .string(name)]) }
            }
        } label: { fieldLabel("Edition", row.target.edition ?? "Standard") }
        .task { await session.loadEditions() }
    }

    private var versionMenu: some View {
        Menu {
            Picker("Version", selection: Binding(get: { row.target.tier }, set: { set(["tier": .string($0)]) })) {
                ForEach(QualityTier.ordered, id: \.self) { Text($0.chipLabel).tag($0.rawValue) }
            }
        } label: { fieldLabel("Version", ManualImportRules.tierLabel(row.target.tier)) }
    }

    private var qualityMenu: some View {
        Menu {
            if let m = row.measured, m.mislabeled == true {
                Section("Name and file disagree") {
                    if let claimed = m.claimedQuality ?? row.parsed.quality {
                        Button("\(DetailText.quality(claimed)) · from the name") { set(["mismatch_choice": "name"]) }
                    }
                    if let measured = m.quality {
                        let size = row.probe.flatMap { p in p.width.map { "\($0)×\(p.height ?? 0)" } } ?? ""
                        Button("\(DetailText.quality(measured)) · measured \(size)") { set(["mismatch_choice": "measured"]) }
                    }
                }
            }
            Picker("Quality", selection: Binding(get: { row.quality ?? "UNKNOWN" }, set: { set(["quality": .string($0)]) })) {
                ForEach(ManualImportRules.qualityOrder, id: \.self) { Text(DetailText.quality($0)).tag($0) }
            }
        } label: { fieldLabel("Quality", DetailText.quality(row.quality ?? "UNKNOWN")) }
    }

    private var releaseMenu: some View {
        Menu {
            Picker("Release type", selection: Binding(get: { row.releaseType ?? "unknown" }, set: { set(["release_type": .string($0)]) })) {
                ForEach(ManualImportRules.releaseTypes, id: \.value) { Text($0.label).tag($0.value) }
            }
        } label: {
            fieldLabel("Release type", ManualImportRules.releaseTypes.first { $0.value == (row.releaseType ?? "unknown") }?.label ?? "Unknown")
        }
    }

    private func field(_ label: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { fieldLabel(label, value) }.buttonStyle(.plain)
    }

    private func fieldLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label).foregroundStyle(Theme.mut).frame(width: 96, alignment: .leading)
            Text(value).foregroundStyle(Theme.txt).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
        }
        .font(.system(size: 13.5))
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
