import SwiftUI
import Charts
import FusionhaKit

/// The approver's Insights lane (web A4 `RequestInsights`): four tiles
/// (requests this week, median time to available, approval rate, approved
/// automatically), requests decided per day by outcome, then top requesters,
/// most wanted and decline reasons over the last 30 days.
struct RequestInsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var data: RequestInsights?
    @State private var failed = false

    private static let none30 = "No requests decided in the last 30 days"

    private static func wantedName(_ w: RequestInsights.Wanted) -> String {
        guard let title = w.title else { return "TMDB #\(w.tmdbId)" }
        return w.year.map { "\(title) (\($0))" } ?? title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Insights").font(Theme.display(26)).foregroundStyle(Theme.txt)
            if let data {
                tiles(data)
                card("Requests decided per day") { OutcomeChart(days: data.perDay) }
                card("Top requesters") {
                    RankList(items: data.topRequesters.map { ($0.person.displayName, $0.requests) }, color: Theme.i1,
                             empty: "No requests in the last 30 days")
                }
                card("Most wanted") {
                    RankList(items: data.mostWanted.map { w in (Self.wantedName(w), w.people) },
                             color: Theme.i2, empty: "Nothing requested in the last 30 days")
                }
                card("Decline reasons") {
                    RankList(items: data.declineReasons.map { (RequestInsights.reasonLabel($0.reason), $0.count) }, color: Theme.danger,
                             empty: "No requests declined in the last 30 days")
                }
            } else {
                Text(failed ? "Insights are unavailable right now. We will try again shortly." : "Loading insights…")
                    .font(.subheadline).foregroundStyle(Theme.mut)
            }
        }
        .task {
            guard let client = model.client else { return }
            do { data = try await client.requestInsights(weeks: 12) } catch { failed = true }
        }
    }

    private func tiles(_ d: RequestInsights) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(label: "Requests this week", value: "\(d.requestsThisWeek)",
                     detail: d.requestsChangePct.map { "\(RequestInsights.signed($0)) vs last week" } ?? (d.requestsThisWeek == 0 ? "No requests this week" : nil),
                     tone: d.requestsChangePct.map { $0 >= 0 ? Theme.done : Theme.danger },
                     series: d.weekly.map { Double($0.requests) }, color: Theme.i1)
            StatTile(label: "Median time to available",
                     value: d.medianHoursToAvailable.map { RequestInsights.hours($0) } ?? Self.none30,
                     detail: d.typicalApprovalHours.map { "Approval typically \(RequestInsights.hours($0))" } ?? "from request to on disk",
                     series: d.weekly.map { $0.medianHoursToAvailable ?? 0 }, color: Theme.done)
            StatTile(label: "Approval rate", value: d.approvalRate.map { RequestInsights.percent($0) } ?? Self.none30,
                     detail: "of requests decided", color: Theme.i2)
            StatTile(label: "Approved automatically", value: d.autoShare.map { RequestInsights.percent($0) } ?? Self.none30,
                     detail: "by a rule or their own grant", color: Theme.i1)
        }
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// One headline number, its line under it, and a sparkline when there is a series.
private struct StatTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    var tone: Color? = nil
    var series: [Double] = []
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            Text(value).font(value.count > 8 ? .system(size: 13, weight: .semibold) : Theme.display(30))
                .foregroundStyle(value.count > 8 ? Theme.mut : Theme.txt)
                .lineLimit(2).minimumScaleFactor(0.7)
            if let detail { Text(detail).font(.caption).foregroundStyle(tone ?? Theme.mut).lineLimit(2) }
            if series.count > 1 {
                Chart(Array(series.enumerated()), id: \.offset) { point in
                    LineMark(x: .value("Week", point.offset), y: .value("Value", point.element))
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 28)
                .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// Requests decided per day, stacked by outcome.
private struct OutcomeChart: View {
    let days: [RequestInsights.Day]

    private struct Bar: Identifiable { let id: String; let day: String; let outcome: String; let count: Int }

    var body: some View {
        let bars = days.flatMap { d in
            [("Approved by admin", d.admin), ("Auto-approved", d.auto), ("Declined", d.declined)]
                .map { Bar(id: d.day + $0.0, day: String(d.day.suffix(5)), outcome: $0.0, count: $0.1) }
        }
        if days.allSatisfy({ $0.admin + $0.auto + $0.declined == 0 }) {
            Text("No requests decided in the last 14 days").font(.subheadline).foregroundStyle(Theme.mut)
        } else {
            Chart(bars) { b in
                BarMark(x: .value("Day", b.day), y: .value("Requests", b.count))
                    .foregroundStyle(by: .value("Outcome", b.outcome))
            }
            .chartForegroundStyleScale(["Approved by admin": Theme.i1, "Auto-approved": Theme.done, "Declined": Theme.danger])
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: 160)
        }
    }
}

/// A ranked list with proportional bars.
private struct RankList: View {
    let items: [(String, Int)]
    let color: Color
    let empty: String

    var body: some View {
        if items.isEmpty {
            Text(empty).font(.subheadline).foregroundStyle(Theme.mut)
        } else {
            let top = max(items.map(\.1).max() ?? 1, 1)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.0).font(.system(size: 13.5)).foregroundStyle(Theme.txt).lineLimit(1)
                            Spacer()
                            Text("\(item.1)").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.txt)
                        }
                        GeometryReader { g in
                            Capsule().fill(color.opacity(0.8)).frame(width: max(4, g.size.width * CGFloat(item.1) / CGFloat(top)))
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
    }
}
