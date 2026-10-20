import SwiftUI
import FusionhaKit

/// Activity › Queue when nothing is downloading (web `QueueIdle`, approved mock
/// `design/mocks/queue-empty.html`): "Queue clear" with readiness, what airs in
/// the next 48 h, and what just landed. One order at every width: hero (the
/// strip on a phone) → readiness tiles → Coming up next → Recently finished.
/// The layout follows the width this view gets (`IdleLayout`, the web's
/// `queueidle` container): a folded Duo / phone is the strip with a 2-column
/// tile grid; unfolded it is the full hero, and from 940 pt the two cards sit
/// side by side when `balance` says they match.
struct QueueClearView: View {
    /// The queue just emptied: pop the check, slide the freshest import in.
    var celebrate = false
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @State private var feed = QueueIdleFeed()
    /// The measured width; nothing is laid out before it (no phone-sized seed
    /// that then jumps to the wide layout on an unfolded Duo).
    @State private var width: CGFloat?

    var body: some View {
        Group {
            if let width {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    content(now: context.date, width: width)
                }
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task { await feed.run(model.client) }
    }

    private func content(now: Date, width: CGFloat) -> some View {
        let coming = feed.calendar.map { IdleComingUp.derive($0, now: now) }
        let recent = feed.imports.map { IdleRecent.derive($0, limit: IdleRecent.max) }
        let balance = IdleLayout.balance(coming: coming, recent: recent)
        let w = Double(width)
        let compact = IdleLayout.width(w) == .phone
        let recentRows = recent.map { Array($0.prefix(IdleLayout.visibleRecent(width: w, balance))) }
        let comingCard = ComingUpNext(coming: coming, failed: feed.calendarFailed, now: now, compact: compact) {
            model.tab = .calendar
        }
        let recentCard = RecentlyFinished(rows: recentRows, failed: feed.importsFailed, celebrate: celebrate,
                                          compact: compact, hideExtra: w <= 420, openHistory: openHistory)
        return VStack(alignment: .leading, spacing: 16) {
            QueueClearHero(summary: feed.summary, failed: feed.summaryFailed, episodes48h: coming?.episodes,
                           celebrate: celebrate, playful: feed.playful, quipSeed: recent?.first?.title ?? "queue",
                           compact: compact,
                           tileColumns: IdleLayout.balancedTileColumns(width: w, gridWidth: w - (compact ? 24 : 44),
                                                                          tiles: compact ? 4 : 5),
                           openHistory: openHistory)
            if IdleLayout.sideBySide(width: w, balance) {
                // `minmax(0, 1.2fr) minmax(0, 1fr)` with a 16 pt gap.
                let comingWidth = max(0, (width - 16) * 1.2 / 2.2)
                HStack(alignment: .top, spacing: 16) {
                    comingCard.frame(width: comingWidth)
                    recentCard.frame(maxWidth: .infinity)
                }
            } else {
                comingCard
                recentCard
            }
        }
    }

    private func openHistory() { chrome.tab = .history }
}
