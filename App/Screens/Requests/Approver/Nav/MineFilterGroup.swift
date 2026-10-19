import SwiftUI
import FusionhaKit

/// Mine's three groups (web `MineGroups`): Show with the server's counts
/// (they follow the source filter), Source (Any · All automatic · Plex ·
/// Letterboxd, then one pill per list of that provider, counted from the
/// unfiltered buckets) and Type (Requests · Issues).
struct MineFilterGroup: View {
    let section: RequestsFilter.Section
    @Environment(RequestsNav.self) private var nav
    @Environment(AppModel.self) private var model
    @State private var counts: RequestCounts?

    private var values: RequestsFilter.Values { nav.filter[.mine] }
    private var sourceKey: String { (values.mineSource?.query ?? []).map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&") }

    var body: some View {
        switch section {
        case .mineShow:
            RequestsFilterPills(title: "Show") {
                ForEach(MyRequestsView.Filter.allCases, id: \.self) { f in
                    RequestsFilterOption(title: f.title, count: f.count(counts), on: values.mineStatus == f) {
                        nav.filter[.mine].mineStatus = f
                    }
                }
            }
            .task(id: sourceKey) {
                counts = try? await model.client?.requestCounts(view: "mine", extra: values.mineSource?.query ?? [])
            }
        case .mineKind:
            RequestsFilterPills(title: "Type") {
                RequestsFilterOption(title: "Requests", on: !values.mineIssues) { nav.filter[.mine].mineIssues = false }
                RequestsFilterOption(title: "Issues", on: values.mineIssues) { nav.filter[.mine].mineIssues = true }
            }
        default:
            source
        }
    }

    private var source: some View {
        let current = values.mineSource
        let subs = current.map { RequestSourceFilter.subs(nav.mineCounts?.bySource ?? [], provider: $0.provider) } ?? []
        return VStack(alignment: .leading, spacing: 4) {
            RequestsFilterPills(title: "Source") {
                RequestsFilterOption(title: "Any", on: current == nil) { nav.filter[.mine].mineSource = nil }
                ForEach(RequestSourceFilter.Provider.allCases, id: \.self) { p in
                    RequestsFilterOption(title: p.title, on: current?.provider == p && current?.sub == nil) {
                        nav.filter[.mine].mineSource = RequestSourceFilter(provider: p)
                    }
                }
            }
            if let current, !subs.isEmpty {
                ActFlow(spacing: 8, lineSpacing: 0) {
                    ForEach(subs, id: \.self) { bucket in
                        let sub = RequestSourceFilter.Sub(bucket)
                        RequestsFilterOption(title: RequestSourceFilter.subLabel(bucket), count: bucket.count, on: current.sub == sub) {
                            nav.filter[.mine].mineSource = RequestSourceFilter(provider: current.provider, sub: sub)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Which source")
            }
        }
    }
}
