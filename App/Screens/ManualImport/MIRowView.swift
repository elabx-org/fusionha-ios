import SwiftUI
import FusionhaKit

/// One file (the web's `PhoneRow`): a tick on every row (select is not
/// import), then three lines that open the row: code and title; quality,
/// version, size and status; and the dim video · audio · group line.
struct MIRowView: View {
    let row: ManualImportRow
    @Binding var openId: Int?
    @Environment(ManualImportSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var open: Bool { openId == row.rowId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                checkbox
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { openId = open ? nil : row.rowId }
                } label: { lines }
                .buttonStyle(.plain)
                .accessibilityHint(open ? "Closes the file" : "Opens the file")
            }
            notes
            if open {
                MIRowBody(row: row)
                    .padding(.top, 6)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
        .padding(.leading, 4)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            shape.fill(Theme.panel).overlay(shape.fill(wash))
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
    }

    /// A faint status wash over the solid row (content stays solid, never glass).
    private var wash: Color {
        guard !row.committed else { return .clear }
        switch row.status {
        case "no_match": return Theme.danger.opacity(0.07)
        case "needs_attention": return Theme.miss.opacity(0.06)
        default: return .clear
        }
    }

    private var checkbox: some View {
        let on = session.selected.contains(row.rowId)
        return Button { session.toggle(row) } label: {
            Image(systemName: row.committed ? "checkmark.seal.fill" : on ? "checkmark.square.fill" : "square")
                .font(.system(size: 20))
                .foregroundStyle(row.committed ? Theme.done : on ? Theme.i1 : Theme.dim)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(row.committed)
        .accessibilityLabel("Select \(row.filename)")
        .accessibilityValue(on ? "Selected" : "Not selected")
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleLine
            HStack(spacing: 8) {
                Text(DetailText.quality(row.quality ?? "UNKNOWN"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(row.quality == nil ? Theme.miss : Theme.txt)
                if row.match.itemId != nil, let tier = QualityTier(rawValue: row.target.tier) { TierPill(tier: tier) }
                Text(DetailText.bytes(row.size)).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                MIStatusBadge(row: row)
            }
            Text(ManualImportCompare.summaryLine(row))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.dim)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if row.match.itemId == nil {
                Label("No match", systemImage: "xmark.circle").foregroundStyle(Theme.danger)
            } else if row.target.isSeries {
                if let code = ManualImportRules.episodeCode(row) {
                    Text(code).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.i2)
                }
                let titles = episodeTitles
                Text(titles.first ?? row.match.title ?? "—").lineLimit(1)
                if titles.count > 1 { Text("+ \(titles.count - 1) more").foregroundStyle(Theme.mut) }
            } else {
                Text(row.match.title ?? row.parsed.title ?? "—").lineLimit(1)
                if let edition = row.target.edition { Text(edition).foregroundStyle(Theme.edition) }
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .rotationEffect(.degrees(open ? 180 : 0))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.txt)
    }

    private var episodeTitles: [String] {
        guard let item = row.match.itemId, let seasons = session.seasons[item] else { return [] }
        let ids = Set(row.target.coveredEpisodeIds)
        return seasons.flatMap(\.episodes).filter { ids.contains($0.id) }
            .sorted { $0.episodeNumber < $1.episodeNumber }.compactMap(\.title)
    }

    @ViewBuilder private var notes: some View {
        let lines: [(String, Color)] = [
            ManualImportRules.advisory(row).map { ($0, Theme.miss) },
            session.rowErrors[row.rowId].map { ($0, Theme.danger) },
            session.rowWarnings[row.rowId].map { ($0, Theme.miss) },
        ].compactMap { $0 }
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            Text(line.0)
                .font(.system(size: 12.5))
                .foregroundStyle(line.1)
                .padding(.leading, 48)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
