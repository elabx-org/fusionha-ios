import SwiftUI
import FusionhaKit

/// A run's decision trail for this title (mock `trailRow`): what it grabbed
/// or upgraded, each with an UPGRADE / GRAB tag, the release on one line,
/// the version chip, the score and why, then the custom formats behind the
/// score; and what it skipped, folded into one SKIP row of reasons
/// (`TasksLogic.groupByReason`, v1's buckets). Loaded from
/// `GET /api/v1/system/runs/{id}` by the card, only this title's versions.
struct V2RunTrail: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    /// This title's candidates (`V2SearchRunCard` loads them); nil while loading.
    let candidates: [RunCandidate]?
    var failed = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let candidates {
                trail(candidates)
            } else {
                Text(failed ? "The decision trail could not be loaded." : "Loading the decision trail…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The run's candidates for this title's versions. A candidate with no
    /// version counts only when the run itself was this title's, so a
    /// library-wide sweep doesn't bring in other titles' unmatched releases.
    static func mine(_ run: CommandRunDetail, detail: ItemDetail) -> [RunCandidate] {
        let ids = Set(detail.editions.map(\.id))
        return run.candidates.filter { c in c.versionId.map { ids.contains($0) } ?? (run.itemId == detail.id) }
    }

    @ViewBuilder
    private func trail(_ all: [RunCandidate]) -> some View {
        let kept = TasksLogic.dedupe(all.filter { $0.action == "GRAB" || $0.action == "UPGRADE" })
        let passed = all.filter { $0.action == "REJECT" || $0.action == "SKIP" }
        Text("\(all.count) release\(all.count == 1 ? "" : "s") for this title")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(muted)
        if all.isEmpty {
            Text("No releases for this title were considered on this pass.")
                .font(.system(size: 12.5))
                .foregroundStyle(muted)
        }
        ForEach(kept.prefix(4)) { row in
            keptRow(row.rep)
        }
        if !passed.isEmpty { skipped(passed) }
    }

    private func keptRow(_ c: RunCandidate) -> some View {
        let edition = c.versionId.flatMap { id in detail.editions.first(where: { $0.id == id }) }
        let cfs = (c.matched ?? []).map { "\($0.name) \(V2HistoryEvent.score($0.score))" }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 10) {
            tag(c.action == "UPGRADE" ? "UPGRADE" : "GRAB", color: Theme.doneText)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.releaseTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let edition {
                        EditionBadge(tier: edition.tier, state: .onDisk, showsCount: false)
                    }
                    Text([c.cfScore.map { V2HistoryEvent.score($0) }, c.reason.isEmpty ? nil : c.reason]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                        .lineLimit(2)
                }
                if !cfs.isEmpty {
                    Text(cfs)
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func skipped(_ passed: [RunCandidate]) -> some View {
        let groups = TasksLogic.groupByReason(passed)
        let reasons = groups.map { "\($0.total) × \($0.bucket.label)" }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 10) {
            tag("SKIP", color: muted)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(passed.count) release\(passed.count == 1 ? "" : "s") passed over")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                Text(reasons)
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The trail's action tag (mock `.ac`): small caps on a 12% fill.
    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .frame(width: 62, alignment: .leading)
            .accessibilityLabel(text.capitalized)
    }
}
