import SwiftUI
import FusionhaKit

/// Coming up next (web `ComingUpNext`, mock `.coming`): monitored, still-wanted
/// airings in the next 48 h grouped by day, each with its upcoming rails and a
/// live "in 2h 05m"; what is already on disk and what airs later in the footer.
struct ComingUpNext: View {
    let coming: ComingUp?
    let failed: Bool
    let now: Date
    var compact = false
    let openCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IdleCardHeader(icon: "calendar", title: "Coming up next", sub: subtitle, link: "Calendar",
                           compact: compact, action: openCalendar)
            content
            if let coming, !coming.already.isEmpty || !coming.later.isEmpty { footer(coming) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .idleCard()
    }

    private var subtitle: Text? {
        guard let coming, coming.episodes > 0 else { return nil }
        let b = { (n: Int) in Text("\(n)").fontWeight(.semibold).foregroundColor(Theme.txt) }
        return b(coming.episodes) + Text(" episode\(coming.episodes == 1 ? "" : "s") · ")
            + b(coming.titles) + Text(" title\(coming.titles == 1 ? "" : "s") · next 48h")
    }

    @ViewBuilder
    private var content: some View {
        if let coming {
            if coming.days.isEmpty {
                IdleCalm(icon: "calendar", title: "Nothing airs in the next 48 hours",
                         message: "Monitored titles are grabbed automatically as they air.", compact: compact)
            } else {
                autoChip
                ForEach(coming.days) { day in
                    dayHeader(day)
                    ForEach(day.rows) { row in
                        ComingUpRow(row: row, now: now, compact: compact)
                    }
                }
                Color.clear.frame(height: 6)
            }
        } else {
            IdleCalm(message: failed ? "The calendar could not be loaded." : "Loading the calendar…", compact: compact)
        }
    }

    private var autoChip: some View {
        Label {
            Text("Monitored — grabbed automatically as each one airs").lineLimit(1).truncationMode(.tail)
        } icon: {
            Image(systemName: "arrow.down.to.line").font(.system(size: 11, weight: .bold))
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Theme.unaired)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.unaired.opacity(0.12), in: Capsule())
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.bottom, 4)
    }

    private func dayHeader(_ day: ComingDay) -> some View {
        HStack(spacing: 8) {
            (Text(IdleTime.dayLabel(day.day, now: now).uppercased()) + Text(" ")
             + Text(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                .foregroundColor(Theme.mut)
             + Text(" · \(day.count)"))
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.top, 12)
        .padding(.bottom, compact ? 4 : 6)
        .accessibilityAddTraits(.isHeader)
    }

    private func footer(_ coming: ComingUp) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if !coming.already.isEmpty {
                ComingAsideLine(label: "Already have", items: coming.already, suffix: " — on disk before it airs ✓",
                                compact: compact)
            }
            if !coming.later.isEmpty {
                ComingAsideLine(label: "Later", items: coming.later, suffix: nil, compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.top, 11)
        .padding(.bottom, 13)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// One footer line (`.line`): an uppercase label, then `Title S01E01 · HD`.
private struct ComingAsideLine: View {
    let label: String
    let items: [ComingAside]
    let suffix: String?
    let compact: Bool

    var body: some View {
        let layout = compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                             : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(0.7)
                .foregroundStyle(Theme.dim)
                .frame(width: compact ? nil : 92, alignment: .leading)
            text.font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
    }

    private var text: Text {
        var out = Text("")
        for (i, a) in items.enumerated() {
            if i > 0 { out = out + Text(" · ") }
            out = out + Text(a.title).fontWeight(.semibold).foregroundColor(Theme.txt)
            if !a.se.isEmpty { out = out + Text(" \(a.se)") }
            let tiers = a.tiers.map(\.pill).joined(separator: "·")
            out = out + Text(a.note.map { " (\($0), \(tiers))" } ?? " · \(tiers)")
        }
        if let suffix { out = out + Text(suffix).foregroundColor(Theme.done) }
        return out
    }
}
