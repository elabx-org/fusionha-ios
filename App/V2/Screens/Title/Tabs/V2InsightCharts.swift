import SwiftUI
import FusionhaKit

/// Insights' score progression: one module per version (two to a row when
/// there are two or more), its media badge and "now +4,050" over the
/// one-ink spark of its import scores.
struct V2ScoreProgressionGrid: View {
    @Environment(\.pagePalette) private var page
    let series: [HistoryInsightsLogic.Series]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                            count: series.count > 1 ? 2 : 1)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(series) { module($0) }
        }
    }

    private func module(_ s: HistoryInsightsLogic.Series) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                EditionBadge(tier: s.tier, state: s.points.isEmpty ? .missing : .onDisk, showsCount: false)
                if let name = V2InsightNames.edition(s.label, tier: s.tier) {
                    Text(name).lineLimit(1)
                }
                if let last = s.points.last {
                    Text("now \(V2HistoryEvent.score(last.score))").monospacedDigit().lineLimit(1)
                }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            if s.points.isEmpty {
                Text("No imports yet")
                    .font(.system(size: 12))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(height: 64, alignment: .center)
            } else {
                V2InsightSpark(points: s.points.map(\.score)).frame(height: 64)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.label) score progression"
            + (s.points.last.map { ", now \(V2HistoryEvent.score($0.score))" } ?? ", no imports yet"))
    }
}

/// Insights' provenance: per version its badge and a one-ink lane, one
/// segment per release that held the slot (older ones quieter, the current
/// one solid), the current release under it, then a shared time axis.
struct V2ProvenanceCard: View {
    @Environment(\.pagePalette) private var page
    let lanes: [HistoryInsightsLogic.Lane]
    let start: Date

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var end: Date { max(Date(), start.addingTimeInterval(3600)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(lanes) { lane in
                HStack(alignment: .top, spacing: 10) {
                    EditionBadge(tier: lane.tier, state: lane.segments.isEmpty ? .missing : .onDisk, showsCount: false)
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        if lane.segments.isEmpty {
                            Text("Nothing grabbed yet").font(.system(size: 12)).foregroundStyle(muted)
                        } else {
                            bar(lane).frame(height: 12)
                            if let current = lane.segments.last { caption(current, lane: lane) }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            axis.padding(.leading, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle()
    }

    private func bar(_ lane: HistoryInsightsLogic.Lane) -> some View {
        let total = end.timeIntervalSince(start)
        let count = lane.segments.count
        return GeometryReader { geo in
            let gaps = CGFloat(max(0, count - 1)) * 2
            let room = max(0, geo.size.width - gaps)
            HStack(spacing: 2) {
                ForEach(Array(lane.segments.enumerated()), id: \.offset) { i, seg in
                    let span = max(seg.end.timeIntervalSince(seg.start), total * 0.02)
                    Rectangle()
                        .fill(ink.opacity(Self.opacity(index: i, count: count)))
                        .frame(width: room * Self.fraction(span, of: total))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, room * Self.fraction(lane.segments[0].start.timeIntervalSince(start), of: total))
        }
        .clipShape(Capsule())
        .background(Capsule().fill(muted.opacity(0.18)))
        .accessibilityHidden(true)
    }

    /// `part` of `whole` as 0...1 (a lane's offset or a segment's width).
    static func fraction(_ part: TimeInterval, of whole: TimeInterval) -> CGFloat {
        CGFloat(min(1, max(0, part / max(whole, 1))))
    }

    /// The current release solid, the ones before it quieter the older they are.
    static func opacity(index: Int, count: Int) -> Double {
        if index == count - 1 { return 0.95 }
        let back = count - 1 - index
        return max(0.2, 0.5 - Double(back - 1) * 0.25)
    }

    private func caption(_ seg: HistoryInsightsLogic.Segment, lane: HistoryInsightsLogic.Lane) -> some View {
        var text = Text(seg.title).foregroundColor(ink).fontWeight(.semibold)
        if let score = seg.score { text = text + Text(" · \(V2HistoryEvent.score(score))") }
        if let name = V2InsightNames.edition(lane.label, tier: lane.tier) { text = Text("\(name) · ") + text }
        return text
            .font(.system(size: 12))
            .foregroundStyle(muted)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var axis: some View {
        let mid = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        return HStack {
            Text(Self.tick(start, span: end.timeIntervalSince(start)))
            Spacer()
            Text(Self.tick(mid, span: end.timeIntervalSince(start)))
            Spacer()
            Text(Self.tick(end, span: end.timeIntervalSince(start)))
        }
        .font(.system(size: 10.5).monospacedDigit())
        .foregroundStyle(muted)
        .accessibilityHidden(true)
    }

    /// Times within a day ("13:04"), dates beyond it ("3 Nov").
    static func tick(_ date: Date, span: TimeInterval) -> String {
        span <= 86_400
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated))
    }
}

enum V2InsightNames {
    /// A named edition ("Black & White") without its tier, nil for a plain
    /// version (the badge already says HD or 4K).
    static func edition(_ label: String, tier: QualityTier) -> String? {
        guard label != tier.chipLabel else { return nil }
        let name = label.replacingOccurrences(of: " · \(tier.chipLabel)", with: "")
        return name.isEmpty ? nil : name
    }
}
