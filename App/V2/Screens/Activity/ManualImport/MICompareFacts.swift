import SwiftUI
import FusionhaKit

/// Yours against this download (mock `mi-cmp`): runtime, release, size and
/// score, each from the server's probe and scores. Where this download
/// loses (shorter, lower score) its value is in the held ink; the better
/// value is bold. A file with nothing in its slot shows this download alone.
struct MICompareFacts: View {
    let row: ManualImportRow
    @Environment(\.pagePalette) private var page

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
            if let ef = row.existingFile {
                GridRow {
                    Text("")
                    head("Yours")
                    head("This download")
                }
                if let t = MIProblemGrouping.runtimes(row) {
                    fact("Runtime", "\(t.yours) min", "\(t.this) min", theirsWins: compare(t.this, t.yours))
                }
                fact("Release", MIProblemCopy.releaseName(ef.releaseGroup, ef.quality),
                     MIProblemCopy.releaseName(row.parsed.releaseGroup, row.quality), theirsWins: nil)
                fact("Size", ef.size.map { DetailText.bytes($0) } ?? "—", DetailText.bytes(row.size), theirsWins: nil)
                if ef.cfScore != nil || row.incomingCf?.score != nil {
                    fact("Score", ef.cfScore.map(MIProblemCopy.signed) ?? "—",
                         row.incomingCf?.score.map(MIProblemCopy.signed) ?? "—",
                         theirsWins: compare(row.incomingCf?.score, ef.cfScore))
                }
            } else {
                GridRow {
                    Text("")
                    head("This download")
                }
                single("Release", MIProblemCopy.releaseName(row.parsed.releaseGroup, row.quality))
                single("Size", DetailText.bytes(row.size))
                if let score = row.incomingCf?.score { single("Score", MIProblemCopy.signed(score)) }
            }
        }
        .font(.system(size: 12.5).monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var ink: Color { page?.ink ?? Theme.txt }

    /// True when this download's value is higher, false when lower, nil when equal or unknown.
    private func compare(_ theirs: Int?, _ yours: Int?) -> Bool? {
        guard let theirs, let yours, theirs != yours else { return nil }
        return theirs > yours
    }

    private func head(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(muted)
    }

    private func key(_ text: String) -> some View {
        Text(text).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(muted)
    }

    private func fact(_ label: String, _ yours: String, _ theirs: String, theirsWins: Bool?) -> some View {
        GridRow {
            key(label)
            Text(yours)
                .fontWeight(theirsWins == false ? .bold : .regular)
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(theirs)
                .fontWeight(theirsWins == nil ? .regular : .bold)
                .foregroundStyle(theirsWins == false ? Theme.stuckText : ink)
                .lineLimit(1)
        }
    }

    private func single(_ label: String, _ value: String) -> some View {
        GridRow {
            key(label)
            Text(value).foregroundStyle(ink).lineLimit(1)
        }
    }
}
