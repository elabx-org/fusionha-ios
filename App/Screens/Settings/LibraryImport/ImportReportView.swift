import SwiftUI
import FusionhaKit

/// The committed import's report (web `CommitReportCard`): the stat row, the
/// Added list (expanded), the empty groups dimmed, and the live analysis count.
/// Re-opening a finished import ("View report") shows the same, read-only.
struct ImportReportView: View {
    let result: LibraryImportCommitResult
    let model: ImportWorkspaceModel
    let onClose: () -> Void
    @State private var addedOpen = true

    var body: some View {
        let report = LibraryImportReport(result: result, items: model.items)
        let needsYou = model.triage.needsYou.count
        List {
            Section {
                ImportSessionStateLine(model: model)
                stats(report, needsYou: needsYou)
            } footer: {
                Text("Adopted in place — nothing moved on disk. Posters + media info fill in over the next few minutes.")
            }
            .listRowBackground(Theme.card)
            Section {
                Button {
                    addedOpen.toggle()
                } label: {
                    LabeledContent("Added", value: "\(LibraryImportRules.plural(report.added.count, "title")) · \(LibraryImportRules.plural(report.filesAdopted, "file"))")
                }
                .buttonStyle(.plain)
                .accessibilityValue(addedOpen ? "Expanded" : "Collapsed")
                if addedOpen {
                    ForEach(report.added) { row in addedRow(row) }
                }
                group("Needs you", needsYou == 0 ? "0 — all matched" : LibraryImportRules.grouped(needsYou), dim: needsYou == 0)
                group("Skipped", LibraryImportRules.grouped(report.skipped), dim: report.skipped == 0)
                group("Failed", "0", dim: true)
            }
            .listRowBackground(Theme.card)
            if let enrichment = model.session?.enrichment, (enrichment.total ?? 0) > 0 {
                Section {
                    Text("Media enrichment running · \(LibraryImportRules.grouped(enrichment.enriched ?? 0)) / \(LibraryImportRules.grouped(enrichment.total ?? 0)) analysed")
                        .font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.mut)
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
    }

    private func stats(_ report: LibraryImportReport, needsYou: Int) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            stat(report.added.count, "Added", Theme.done)
            stat(report.filesAdopted, "Files adopted", Theme.txt)
            stat(report.updated, "Updated", Theme.txt)
            stat(report.skipped, "Skipped", Theme.dim)
            stat(needsYou, "Needs you", Theme.miss)
            stat(0, "Failed", Theme.danger)
        }
        .padding(.vertical, 6)
    }

    private func stat(_ n: Int, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LibraryImportRules.grouped(n))
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(n == 0 ? Theme.dim : tint)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addedRow(_ row: LibraryImportAddedRow) -> some View {
        HStack(spacing: 8) {
            Text(row.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            if let year = row.year { Text(String(year)).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            Spacer(minLength: 6)
            ForEach(Array(row.tiers.enumerated()), id: \.offset) { _, t in TierPill(tier: t) }
            Text(LibraryImportRules.plural(row.files, "file")).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.mut)
        }
    }

    private func group(_ label: String, _ value: String, dim: Bool) -> some View {
        LabeledContent(label, value: value).opacity(dim ? 0.55 : 1)
    }
}
