import SwiftUI
import FusionhaKit

// The History tab's Timeline: one card per day, with same-minute runs of one
// event kind folded into a single row ("Numbering fixed · 5 episodes").

struct HistoryTimeline: View {
    let detail: ItemDetail
    let entries: [HistoryEntry]

    private var days: [(String, [[HistoryEntry]])] {
        var out: [(String, [HistoryEntry])] = []
        let cal = Calendar.current
        for entry in entries {
            let date = DetailText.instant(entry.createdAt) ?? .distantPast
            let key: String
            if cal.isDateInToday(date) { key = "TODAY" }
            else if cal.isDateInYesterday(date) { key = "YESTERDAY" }
            else { key = date.formatted(.dateTime.month(.abbreviated).day()).uppercased() }
            if out.last?.0 == key { out[out.count - 1].1.append(entry) } else { out.append((key, [entry])) }
        }
        return out.map { day in
            (day.0, HistoryRuns.runs(day.1) { e in
                HistoryRuns.key(eventType: e.eventType, editionId: e.editionId, date: DetailText.instant(e.createdAt))
            })
        }
    }

    var body: some View {
        let days = days
        VStack(alignment: .leading, spacing: 12) {
            ForEach(days.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 0) {
                    Text(days[i].0)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.dim)
                        .padding(.leading, 4)
                        .padding(.bottom, 12)
                    ForEach(days[i].1, id: \.first!.id) { run in
                        if run.count == 1 {
                            TimelineRow(detail: detail, entry: run[0])
                        } else {
                            TimelineRunRow(detail: detail, run: run)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface(radius: 14, flatFill: Theme.panel2)
            }
        }
    }
}

/// A folded run: the kind and a count, the titles under it (first three, then "Show all").
struct TimelineRunRow: View {
    let detail: ItemDetail
    let run: [HistoryEntry]
    @State private var expanded = false
    private static let preview = 3

    var body: some View {
        let style = eventStyle(run[0].eventType)
        let noun = detail.isSeries ? "episodes" : "events"
        let titles = run.map { $0.sourceTitle ?? style.label }
        let shown = expanded ? titles : Array(titles.prefix(Self.preview))
        HStack(alignment: .top, spacing: 12) {
            TimelineNode(color: style.color, mono: style.mono)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(style.label) · \(run.count) \(noun)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                ForEach(shown.indices, id: \.self) { i in
                    Text(shown[i])
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                if titles.count > Self.preview {
                    Button(expanded ? "Show less" : "Show all \(titles.count)") { expanded.toggle() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accentText)
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            TimelineWhen(createdAt: run[0].createdAt)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
    }
}

/// The timeline's spine and status node.
struct TimelineNode: View {
    let color: Color
    let mono: MonoToken?

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity)
            Group {
                if let mono { StatusSwatch(mono) } else { Circle().fill(color) }
            }
            .frame(width: 13, height: 13)
            .padding(3)
            .background(color.opacity(0.18), in: Circle())
            .padding(.top, 2)
        }
        .frame(width: 20)
    }
}

/// "3 weeks ago" over "19:36".
struct TimelineWhen: View {
    let createdAt: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(DetailText.relative(createdAt)).font(.system(size: 12)).foregroundStyle(Theme.mut)
            if let date = DetailText.instant(createdAt) {
                Text(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .fixedSize()
    }
}
