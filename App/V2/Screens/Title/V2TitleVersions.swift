import SwiftUI
import FusionhaKit

/// One version's numbers on the v2 title page: its T5 badge state, the
/// one-ink rail and the card's lines, from v1's `VersionSummary` (built once
/// per load in `DetailStore`) and the title's live queue rows.
struct V2TitleVersion: Identifiable {
    let edition: DetailEdition
    let state: EditionBadgeState
    /// On disk, aired (have + the aired rest) and tracked episodes; a movie is 0 or 1 of 1.
    let have: Int
    let aired: Int
    let total: Int
    /// "6/7", or nil for a movie.
    let count: String?
    /// "12.4 GB · Missing 1".
    let line: String
    var id: Int { edition.id }

    var rest: OneInkRail.Piece { OneInkRail.rest(for: state) }

    @MainActor
    init(edition: DetailEdition, store: DetailStore, detail: ItemDetail) {
        self.edition = edition
        let summary = store.summary(edition)
        let live = V2TitleVersion.live(store.queue, editionId: edition.id)
        state = V2TitleVersion.state(edition, detail: detail, summary: summary, live: live)
        if detail.isSeries {
            let c = summary?.cover ?? Cover()
            have = c.owned
            total = c.total
            aired = max(c.owned, c.total - c.unaired)
            count = c.total > 0 ? "\(c.owned)/\(c.total)" : nil
            let size = Format.bytes(summary?.bytes)
            line = [size == "—" ? nil : size, summary?.status.text].compactMap { $0 }.joined(separator: " · ")
        } else {
            let file = edition.movieFile
            have = file == nil ? 0 : 1
            aired = 1
            total = 1
            count = nil
            let size = Format.bytes(file?.size)
            let quality = file?.quality.map { DetailText.quality($0) } ?? summary?.status.text
            // No file and nothing in flight, but proven out early: say so
            // instead of "Missing" (web `version-early.ts`).
            if file == nil, live.isEmpty, state == .missing, let early = edition.earlyRelease {
                line = EarlyReleaseCopy.headline(early)
            } else {
                line = [size == "—" ? nil : size, quality].compactMap { $0 }.joined(separator: " · ")
            }
        }
    }

    /// The version's rows still in the queue.
    static func live(_ queue: [QueueItem], editionId: Int) -> [QueueItem] {
        queue.filter {
            $0.editionId == editionId && !["completed", "failed"].contains($0.status.lowercased())
        }
    }

    /// Held wins (an attention file, a dead link, a held import), then a live
    /// download or an upgrade, then what is on disk.
    static func state(_ edition: DetailEdition, detail: ItemDetail, summary: VersionSummary?,
                      live: [QueueItem]) -> EditionBadgeState {
        if edition.attentionKind != nil || edition.unresolvedCount > 0 || live.contains(where: { QueueProgress($0).held }) {
            return .held
        }
        if let row = live.first { return .downloading(progress: Double(QueueProgress(row).percent) / 100) }
        if edition.downloadState == "upgrading" { return .downloading(progress: edition.progress.map { $0 / 100 }) }
        guard detail.isSeries else { return edition.movieFile == nil ? .missing : .onDisk }
        guard let c = summary?.cover else { return .missing }
        if c.total == 0 { return c.kept > 0 ? .onDisk : .missing }
        if c.owned >= c.total { return .onDisk }
        if c.owned > 0 { return .partial(have: c.owned, of: c.total) }
        return .missing
    }

    /// The page's versions, HD first.
    @MainActor
    static func all(_ store: DetailStore, detail: ItemDetail) -> [V2TitleVersion] {
        detail.orderedEditions.map { V2TitleVersion(edition: $0, store: store, detail: detail) }
    }
}

/// The title's HD and 4K (the first version of each tier) as one ticket.
struct V2TitleTicket {
    var hd: EditionBadgeState?
    var uhd: EditionBadgeState?

    init(_ versions: [V2TitleVersion]) {
        hd = versions.first { $0.edition.tier == .hd }?.state
        uhd = versions.first { $0.edition.tier == .uhd }?.state
    }
}
