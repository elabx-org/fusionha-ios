import SwiftUI
import FusionhaKit

/// The bulk bar (drafts only): a quality profile per kind present, applied to
/// every matched row whose own kind accepts it, and Monitor All / None.
struct ImportBulkSection: View {
    let model: ImportWorkspaceModel
    @State private var chosen: [MediaKind: Int] = [:]

    private var kinds: [MediaKind] {
        var out: [MediaKind] = []
        for row in model.matched where !out.contains(row.kind) { out.append(row.kind) }
        return out
    }

    var body: some View {
        let kindList = self.kinds
        SettingsSection("Bulk", footer: footer(kindList)) {
            ForEach(kindList, id: \.self) { kind in profileRow(kind, multi: kindList.count > 1) }
            monitorRow
            Text(scopeLine(kindList)).font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
    }

    private func profileRow(_ kind: MediaKind, multi: Bool) -> some View {
        let label = LibraryImportRules.kindLabel(kind)
        let options = LibraryImportRules.bulkOptions(model.matched, kind: kind, profiles: model.profiles)
        let selection = chosen[kind]
        let count = LibraryImportRules.bulkTargets(model.matched, kind: kind, profileId: selection,
                                                   profiles: model.profiles).count
        return VStack(alignment: .leading, spacing: 8) {
            Picker(multi ? "\(label) profile" : "Profile", selection: Binding(
                get: { chosen[kind] },
                set: { chosen[kind] = $0 })) {
                Text("Profile").tag(Int?.none)
                ForEach(options) { p in Text(p.name).tag(Int?.some(p.id)) }
            }
            .pickerStyle(.menu)
            .tint(Theme.mut)
            .accessibilityLabel("Bulk quality profile for \(label)")
            Button(multi ? "Apply to all \(count) \(label)" : "Apply to all \(count)") {
                if let selection { model.applyBulkProfile(selection, kind: kind) }
            }
            .buttonStyle(.web(.primary))
            .disabled(selection == nil)
        }
        .padding(.vertical, 2)
    }

    private var monitorRow: some View {
        let rows = model.matched
        let all = !rows.isEmpty && rows.allSatisfy(\.monitored)
        let none = !rows.isEmpty && rows.allSatisfy { !$0.monitored }
        return LabeledContent("Monitor") {
            HStack(spacing: 6) {
                Button { model.applyBulkMonitor(true) } label: {
                    Label("All", systemImage: all ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.web(all ? .primary : .subtle))
                .accessibilityLabel("Monitor all")
                Button { model.applyBulkMonitor(false) } label: {
                    Label("None", systemImage: "bookmark.slash")
                }
                .buttonStyle(.web(none ? .primary : .subtle))
                .accessibilityLabel("Monitor none")
            }
            .labelStyle(.titleAndIcon)
        }
    }

    private func scopeLine(_ kinds: [MediaKind]) -> String {
        let n = model.matched.count
        let noun = kinds.count == 1 ? (kinds[0] == .series ? "series" : "movies") : "matched"
        let needYou = model.triage.needsYou.filter(\.matched).count
        return "\(LibraryImportRules.grouped(n)) \(noun) · \(LibraryImportRules.grouped(needYou)) need you"
    }

    private func footer(_ kinds: [MediaKind]) -> String {
        let scope = kinds.count > 1
            ? "’s kinds — each picker only touches its own rows"
            : "’s kind (\(LibraryImportRules.kindLabel(kinds.first ?? .movie)))"
        return "Profiles are scoped to this session\(scope). A per-row Override still wins."
    }
}
