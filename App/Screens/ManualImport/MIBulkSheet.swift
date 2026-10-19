import SwiftUI
import FusionhaKit

/// Bulk edit (the web's phone `BulkSheet`): Set version, quality, languages or
/// release type for several files at once. Each is a drill-in page, and the
/// root shows the rows' current value, or Mixed.
struct MIBulkSheet: View {
    let title: String
    let rows: [ManualImportRow]
    /// Pushed from the selection sheet rather than presented on its own.
    var embedded = false
    @Environment(ManualImportSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    private enum Page: Hashable { case version, quality, languages, release }

    /// The rows as they are now (each write re-reads the scan).
    private var live: [ManualImportRow] {
        let ids = Set(rows.map(\.rowId))
        return session.rows.filter { ids.contains($0.rowId) && !$0.committed }
    }

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var content: some View {
        List {
            Section {
                link("Set version", .version) { ManualImportRules.tierLabel($0.target.tier) }
                link("Set quality", .quality) { DetailText.quality($0.quality ?? "UNKNOWN") }
                link("Set languages", .languages) { ($0.languages ?? []).isEmpty ? "Unknown" : ($0.languages ?? []).joined(separator: ", ") }
                if live.contains(where: \.target.isSeries) {
                    link("Set release type", .release) { r in
                        ManualImportRules.releaseTypes.first { $0.value == (r.releaseType ?? "unknown") }?.label ?? "Unknown"
                    }
                }
            } footer: {
                Text("\(live.count) file\(live.count == 1 ? "" : "s") change together.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Page.self) { page(for: $0) }
        .disabled(session.bulkBusy)
        .overlay { if session.bulkBusy { ProgressView().tint(Theme.mut) } }
    }

    private func link(_ label: String, _ page: Page, _ value: @escaping (ManualImportRow) -> String) -> some View {
        NavigationLink(value: page) {
            LabeledContent(label) {
                Text(ManualImportBatch.shared(live, value) ?? "—").foregroundStyle(Theme.mut).lineLimit(1)
            }
        }
        .disabled(live.isEmpty)
    }

    @ViewBuilder private func page(for page: Page) -> some View {
        switch page {
        case .version:
            options("Set version", QualityTier.ordered.map { ($0.rawValue, $0.chipLabel) }, field: "tier")
        case .quality:
            options("Set quality", ManualImportRules.qualityOrder.map { ($0, DetailText.quality($0)) }, field: "quality")
        case .release:
            options("Set release type", ManualImportRules.releaseTypes.map { ($0.value, $0.label) }, field: "release_type")
        case .languages:
            MIBulkLanguages(rows: live)
        }
    }

    /// A single-choice page: the pick applies to every row and closes the sheet.
    private func options(_ title: String, _ values: [(String, String)], field: String) -> some View {
        List(values, id: \.0) { option in
            Button {
                let targets = live
                Task {
                    await session.bulkPatch(targets, [field: .string(option.0)])
                    dismiss()
                }
            } label: {
                Text(option.1).foregroundStyle(Theme.txt)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Set languages for several files: each toggle sends the whole set, as the web does.
private struct MIBulkLanguages: View {
    let rows: [ManualImportRow]
    @Environment(ManualImportSession.self) private var session
    @State private var picked: [String] = []

    var body: some View {
        List(ManualImportRules.languages, id: \.self) { lang in
            let on = picked.contains(lang)
            Button {
                if on { picked.removeAll { $0 == lang } } else { picked.append(lang) }
                let next = picked, targets = rows
                Task { await session.bulkPatch(targets, ["languages": .array(next.map(SettingsJSON.string))]) }
            } label: {
                HStack {
                    Text(lang).foregroundStyle(Theme.txt)
                    Spacer()
                    if on { Image(systemName: "checkmark").foregroundStyle(Theme.accentText) }
                }
            }
            .accessibilityAddTraits(on ? .isSelected : [])
        }
        .navigationTitle("Set languages")
        .navigationBarTitleDisplayMode(.inline)
    }
}
