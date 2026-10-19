import SwiftUI
import FusionhaKit

/// Recently finished (web `RecentlyFinished`, mock `.recent`): the last imports,
/// a season pack folded into one row. After the queue empties (`celebrate`) the
/// freshest row slides in under a short green wash; under Reduce Motion the
/// wash only fades.
struct RecentlyFinished: View {
    let rows: [FinishedRow]?
    let failed: Bool
    let celebrate: Bool
    var compact = false
    /// Under 420 pt the extras (range · audio · group) drop out.
    var hideExtra = false
    let openHistory: () -> Void

    /// An import this recent at mount is the one that just left the queue.
    private static let freshSeconds: TimeInterval = 90

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            VStack(alignment: .leading, spacing: 0) {
                IdleCardHeader(icon: "clock.arrow.circlepath", title: "Recently finished",
                               sub: rows.flatMap { $0.isEmpty ? nil : Text("last \(ActFmt.plural($0.count, "import"))") },
                               link: "View History", compact: compact, action: openHistory)
                content(now: context.date)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .idleCard()
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let rows {
            if rows.isEmpty {
                IdleCalm(title: "Nothing imported yet", message: "Finished downloads land here as they import.",
                         compact: compact)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { IdleRowDivider() }
                    RecentlyFinishedRow(row: row, now: now, compact: compact, hideExtra: hideExtra,
                                        fresh: celebrate && i == 0 && isFresh(row, now: now))
                }
            }
        } else {
            IdleCalm(message: failed ? "History could not be loaded." : "Loading…", compact: compact)
        }
    }

    private func isFresh(_ row: FinishedRow, now: Date) -> Bool {
        guard let at = ServerTime.parse(row.at) else { return false }
        return now.timeIntervalSince(at) < Self.freshSeconds
    }
}

/// One import (`.frow`): poster, title + episode label, tier · quality · extras,
/// and "✓ Imported ×2" with how long ago.
struct RecentlyFinishedRow: View {
    let row: FinishedRow
    let now: Date
    var compact = false
    var hideExtra = false
    let fresh: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var wash: Double
    @State private var landed: Bool

    init(row: FinishedRow, now: Date, compact: Bool = false, hideExtra: Bool = false, fresh: Bool = false) {
        self.row = row
        self.now = now
        self.compact = compact
        self.hideExtra = hideExtra
        self.fresh = fresh
        _wash = State(initialValue: fresh ? 1 : 0)
        _landed = State(initialValue: !fresh)
    }

    var body: some View {
        Button { if let id = row.itemId { model.open(id) } } label: {
            HStack(spacing: 11) {
                ActPoster(url: row.posterUrl, title: row.title, size: .sm)
                main
                when
            }
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 9 : 8)
            .frame(minHeight: compact ? 64 : 60)
            .background(Theme.done.opacity(0.16 * wash))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(landed || reduce ? 1 : 0)
        .offset(y: landed || reduce ? 0 : -10)
        .onAppear(perform: celebrate)
        .accessibilityElement(children: .combine)
    }

    private func celebrate() {
        guard fresh else { return }
        withAnimation(reduce ? nil : .timingCurve(0.22, 1, 0.36, 1, duration: 0.48)) { landed = true }
        withAnimation(.easeOut(duration: 2.4).delay(1.2)) { wash = 0 }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text(row.title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    .lineLimit(1).truncationMode(.tail)
                if !row.label.isEmpty {
                    Text(verbatim: row.label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.mut)
                        .lineLimit(1).fixedSize()
                }
            }
            HStack(spacing: 7) {
                if let tier = row.tier { TierPill(tier: tier) }
                if !row.quality.isEmpty {
                    Text(row.quality).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        .lineLimit(1).layoutPriority(1)
                }
                if !row.extra.isEmpty && !hideExtra {
                    Text(row.extra).font(.system(size: 11.5)).foregroundStyle(Theme.dim).lineLimit(1).truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var when: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label("Imported" + (row.count > 1 ? " ×\(row.count)" : ""), systemImage: "checkmark")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.done)
            Text(ActFmt.relative(row.at, now: now))
                .font(.system(size: 11)).monospacedDigit().foregroundStyle(Theme.dim)
        }
        .lineLimit(1)
        .fixedSize()
    }
}
