import SwiftUI
import FusionhaKit

/// A movie's Cinema · Digital · Physical on the v2 title page: v1's
/// `ReleaseTimeline` (same dates, the server's release windows overridden
/// by the item's own dates, "· est." kept) drawn in the page's inks on a W1
/// card, in the edition badges' language: a release that has happened is
/// a filled disc, one still to come an outline. The line fills up to today,
/// where a dot marks where things stand, and each step says how long ago or
/// how far off it is ("5 days ago", "in 12 weeks"), under a one-line status.
struct V2ReleaseTimeline: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail

    struct Step: Hashable {
        let kind: String
        let date: Date
        let estimated: Bool
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    private var steps: [Step] {
        var byKind: [String: Step] = [:]
        for w in detail.releaseWindows ?? [] {
            guard let kind = w.kind, let date = DetailText.instant(w.date) else { continue }
            byKind[kind] = Step(kind: kind, date: date, estimated: w.estimated ?? false)
        }
        for (kind, raw) in [("cinema", detail.inCinemas), ("digital", detail.digitalRelease),
                            ("physical", detail.physicalRelease)] {
            if let date = DetailText.instant(raw) { byKind[kind] = Step(kind: kind, date: date, estimated: false) }
        }
        return ["cinema", "digital", "physical"].compactMap { byKind[$0] }
    }

    var body: some View {
        let steps = steps
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            Text(ReleaseTimelineCopy.status(steps, now: now))
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(ink)
            HStack(alignment: .top, spacing: 0) {
                ForEach(steps.indices, id: \.self) { i in
                    column(steps, i, now: now)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle()
    }

    private func column(_ steps: [Step], _ i: Int, now: Date) -> some View {
        let step = steps[i]
        let past = step.date <= now
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                disc(step.kind, past: past)
                if i < steps.count - 1 {
                    segment(fill: ReleaseTimelineCopy.progress(from: step.date, to: steps[i + 1].date, now: now))
                }
            }
            Text(ReleaseTimelineCopy.label(step.kind))
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(past ? ink : muted)
            if let near = ReleaseTimelineCopy.near(step.date, now: now) {
                Text(near)
                    .font(.system(size: 11.5, weight: past ? .regular : .semibold))
                    .foregroundStyle(past ? muted : ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(step.date.formatted(.dateTime.month(.abbreviated).day().year()) + (step.estimated ? " · est." : ""))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ReleaseTimelineCopy.label(step.kind)), \(past ? "released" : "coming"), "
            + (ReleaseTimelineCopy.near(step.date, now: now)
                ?? step.date.formatted(.dateTime.month(.wide).day().year())))
    }

    /// Filled with the icon knocked out once it has happened; an outline before.
    private func disc(_ kind: String, past: Bool) -> some View {
        ZStack {
            if past {
                Circle().fill(ink)
                Image(systemName: ReleaseTimelineCopy.icon(kind))
                    .font(.system(size: 12, weight: .semibold))
                    .blendMode(.destinationOut)
            } else {
                Circle().strokeBorder(muted.opacity(0.7), lineWidth: 1.5)
                Image(systemName: ReleaseTimelineCopy.icon(kind))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted)
            }
        }
        .frame(width: 26, height: 26)
        .compositingGroup()
    }

    /// The line to the next step: ink up to today, with today's dot where
    /// it falls between two steps.
    private func segment(fill: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(muted.opacity(0.3)).frame(height: 2)
                Capsule().fill(ink).frame(width: w * fill, height: 2)
                if fill > 0, fill < 1 {
                    Circle().fill(ink)
                        .frame(width: 8, height: 8)
                        .offset(x: w * fill - 4)
                }
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: 26)
        .padding(.horizontal, 4)
    }
}

/// The timeline's words and arithmetic.
enum ReleaseTimelineCopy {
    static func icon(_ kind: String) -> String {
        switch kind {
        case "cinema": return "film"
        case "digital": return "play.tv"
        default: return "opticaldisc"
        }
    }

    static func label(_ kind: String) -> String {
        switch kind {
        case "cinema": return "Cinema"
        case "digital": return "Digital"
        default: return "Physical"
        }
    }

    /// How far today is along the line from one step to the next, 0...1.
    static func progress(from start: Date, to end: Date, now: Date) -> Double {
        guard end > start else { return now >= end ? 1 : 0 }
        return min(1, max(0, now.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    /// The step's relative time while it is close (within a year either
    /// way); an old release just keeps its date ("178 months ago" was noise).
    static func near(_ date: Date, now: Date) -> String? {
        abs(date.timeIntervalSince(now)) < 365 * 86_400 ? relative(date, now: now) : nil
    }

    /// "Today", "Yesterday", "5 days ago", "in 12 weeks", by calendar day.
    static func relative(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default:
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            var parts = DateComponents()
            let n = abs(days)
            if n < 14 { parts.day = days } else if n < 61 { parts.weekOfMonth = days / 7 } else { parts.month = days / 30 }
            return f.localizedString(from: parts)
        }
    }

    /// One line on where things stand: "Out on digital · physical in 12 weeks".
    static func status(_ steps: [V2ReleaseTimeline.Step], now: Date) -> String {
        let out = steps.last { $0.date <= now }
        let next = steps.first { $0.date > now }
        switch (out, next) {
        case let (out?, next?):
            return "Out \(place(out.kind)) · \(label(next.kind).lowercased()) \(relative(next.date, now: now).lowercased())"
        case let (out?, nil):
            return "Out \(place(out.kind))"
        case let (nil, next?):
            return "\(label(next.kind)) release \(relative(next.date, now: now).lowercased())"
        default:
            return "No release dates yet"
        }
    }

    private static func place(_ kind: String) -> String {
        switch kind {
        case "cinema": return "in cinemas"
        case "digital": return "on digital"
        default: return "on disc"
        }
    }
}
