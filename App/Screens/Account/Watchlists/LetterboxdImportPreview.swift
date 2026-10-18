import SwiftUI
import FusionhaKit

/// The READY preview (web `CsvPreview`): the counters, the sample with an
/// Include switch on each low-confidence row, "Include all", how many to
/// request now, and the commit.
struct LetterboxdImportPreview: View {
    let preview: CsvPreviewRead
    let busy: Bool
    let onCommit: (Int, [String]) -> Void
    let onCancel: () -> Void
    @State private var picked: Set<String> = []
    @State private var includeAll = false
    @State private var requestNow = 25

    private var counts: CsvCounts? { preview.counts }
    private var include: [String] { includeAll ? preview.lowConfidence.map(\.key) : Array(picked) }
    private var available: Int { (counts?.matched ?? 0) + include.count }
    private var now: Int { min(requestNow, available) }
    private var wish: Int { available - now }

    var body: some View {
        Section {
            countRow("Matched", counts?.matched ?? 0, Theme.done)
            countRow("Low confidence", counts?.lowConfidence ?? 0, Theme.miss)
            countRow("No match", counts?.unmatched ?? 0, Theme.danger)
            countRow("Already in library", counts?.alreadyHave ?? 0, Theme.unaired)
        }
        Section {
            ForEach(preview.rows) { rowView($0) }
            if !preview.lowConfidence.isEmpty {
                Toggle("Include all \(preview.lowConfidence.count)", isOn: $includeAll)
            }
        } header: {
            Text("In your CSV · matched to")
        } footer: {
            let more = max(0, preview.total - preview.rows.count)
            if more > 0 {
                Text("…and \(more) more rows. Low-confidence matches are left out unless you include them.")
            }
        }
        Section {
            Picker("How many to request right now", selection: $requestNow) {
                ForEach([10, 25, 50, 100], id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            Button("Request \(now) now, wishlist the rest (\(wish))") { onCommit(requestNow, include) }
                .disabled(busy)
            Button("Cancel", role: .cancel, action: onCancel)
        } header: {
            Text("How many to request right now")
        } footer: {
            Text(LetterboxdLogic.importWishHint(wish))
        }
    }

    private func countRow(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundStyle(Theme.txt)
            Spacer()
            Text("\(value)").fontWeight(.semibold).monospacedDigit().foregroundStyle(Theme.txt)
        }
    }

    @ViewBuilder
    private func rowView(_ row: CsvRow) -> some View {
        let source = "\(row.name) (\(Self.year(row.year)))"
        let match = row.matchedTitle.map { title in "\(title) · \(Self.year(row.matchedYear))" } ?? "No match"
        if row.confidence == "LOW" {
            Toggle(isOn: Binding(
                get: { includeAll || picked.contains(row.key) },
                set: { on in if on { picked.insert(row.key) } else { picked.remove(row.key) } }
            )) {
                rowText(source, match)
            }
            .disabled(includeAll)
            .accessibilityLabel("Include \(row.name)")
        } else {
            HStack {
                rowText(source, match)
                Spacer(minLength: 8)
                tag(row.confidence)
            }
        }
    }

    private static func year(_ value: Int?) -> String {
        guard let value else { return "—" }
        return String(value)
    }

    private func rowText(_ source: String, _ match: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source).foregroundStyle(Theme.txt)
            Text(match).font(.caption).foregroundStyle(Theme.mut)
        }
    }

    private func tag(_ confidence: String) -> some View {
        let text: String
        let color: Color
        switch confidence {
        case "HIGH": text = "Matched"; color = Theme.done
        case "HAVE": text = "In library"; color = Theme.unaired
        default: text = "Skipped"; color = Theme.dim
        }
        return Text(text).font(.caption.weight(.semibold)).foregroundStyle(color)
    }
}
