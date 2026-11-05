import SwiftUI
import FusionhaKit

/// A movie's Cinema · Digital · Physical on the v2 title page: v1's
/// `ReleaseTimeline` (same dates, the server's release windows overridden
/// by the item's own dates, "· est." kept) drawn in the page's inks on a W1
/// card. One ink: a release that has happened is solid, one still to come
/// is the quieter ink, and the line between them follows.
struct V2ReleaseTimeline: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail

    private struct Step: Hashable {
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
        HStack(alignment: .top, spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                let step = steps[i]
                let past = step.date <= now
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Image(systemName: icon(step.kind))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(past ? ink : muted)
                            .frame(width: 26, height: 26)
                            .background(ink.opacity(past ? 0.14 : 0.06), in: Circle())
                            .overlay(Circle().strokeBorder(ink.opacity(past ? 0.36 : 0.18)))
                        if i < steps.count - 1 {
                            Rectangle().fill(ink.opacity(past ? 0.32 : 0.12)).frame(height: 2)
                        }
                    }
                    Text(label(step.kind))
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(past ? ink : muted)
                    Text(step.date.formatted(.dateTime.month(.abbreviated).day().year()) + (step.estimated ? " · est." : ""))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle()
    }

    private func icon(_ kind: String) -> String {
        switch kind {
        case "cinema": return "film"
        case "digital": return "play.tv"
        default: return "opticaldisc"
        }
    }

    private func label(_ kind: String) -> String {
        switch kind {
        case "cinema": return "Cinema"
        case "digital": return "Digital"
        default: return "Physical"
        }
    }
}
