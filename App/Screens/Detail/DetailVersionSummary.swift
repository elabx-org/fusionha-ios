import SwiftUI
import FusionhaKit

// The numbers behind the Versions panel (components/detail/versions/*). The
// panel is DetailVersionsPanel; its cards DetailVersionRow / DetailVersionDetail;
// season bars and ticks DetailSeasonBars; banner, Not tracked and Compare
// seasons DetailVersionExtras.

/// One version's numbers, computed once per load in `DetailStore` so `body`
/// never walks the episodes.
struct VersionSummary {
    let dot: EditionDot
    let status: VersionStatusDisplay
    let movieStatus: MovieVersionStatus?
    let cover: Cover
    /// Per-season coverage, keyed by season number.
    let seasonCovers: [Int: Cover]
    let bytes: Double
    let untrackedNote: String?
    let availability: MovieAvailabilityNote?
    let grabbedLabel: String
    let grabbedValue: String

    init(detail: ItemDetail, edition: DetailEdition, activeQueue: Set<Int>, now: Date) {
        dot = detail.dot(for: edition, activeQueueEditionIds: activeQueue)
        if detail.isSeries {
            var covers: [Int: Cover] = [:]
            var total = Cover()
            for season in detail.seasons ?? [] {
                let c = season.cover(editionId: edition.id, now: now)
                covers[season.seasonNumber] = c
                total = total + c
            }
            seasonCovers = covers
            cover = total
            status = seriesVersionStatus(total)
            movieStatus = nil
            bytes = detail.editionBytes(edition)
            untrackedNote = detail.untrackedNote(total)
            availability = nil
            grabbedLabel = "Files"
            grabbedValue = "\(total.owned)/\(total.total) eps · \(DetailText.bytes(bytes))"
        } else {
            let st = detail.movieVersionStatus(edition, base: dot, now: now)
            movieStatus = st
            status = st.display
            cover = Cover()
            seasonCovers = [:]
            bytes = edition.movieFile?.size ?? 0
            untrackedNote = nil
            availability = edition.movieFile == nil && st != .grab
                ? detail.movieAvailabilityNote(edition, status: st, now: now) : nil
            if edition.movieFile != nil {
                let g = detail.versionGrabbed(edition.id, now: now)
                grabbedLabel = g.label
                grabbedValue = g.value
            } else {
                grabbedLabel = "File"
                grabbedValue = "none yet"
            }
        }
    }
}

extension EditionStatus {
    /// The status glyph a version row shows (colour comes from the status).
    var versionGlyph: String {
        switch self {
        case .downloaded: return "checkmark"
        case .downloading: return "arrow.down.circle"
        case .upgrading: return "arrow.up.circle"
        case .upcoming, .unaired: return "clock"
        case .unmonitored: return "bookmark"
        default: return "circle.dashed"
        }
    }
}
