import SwiftUI
import FusionhaKit

/// One group of the filter sheet (web `FilterGroups`), bound to the open
/// view's filters. Mine's three groups live in `MineFilterGroup`.
struct RequestsFilterGroup: View {
    let section: RequestsFilter.Section
    @Environment(RequestsNav.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        let pane = nav.pane
        switch section {
        case .search:
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.dim)
                TextField("Title or person", text: $nav.filter[pane].search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .requester:
            RequestsFilterPills(title: "Requester") {
                option("Anyone", on: nav.filter[pane].requesterId == nil) { $0.requesterId = nil }
                ForEach(nav.people, id: \.id) { p in
                    option(p.displayName, on: nav.filter[pane].requesterId == p.id) { $0.requesterId = p.id }
                }
            }
        case .source:
            RequestsFilterPills(title: "Source") {
                ForEach(RequestOrigin.allCases, id: \.self) { o in
                    option(o.title, on: nav.filter[pane].origins.contains(o)) { v in
                        if v.origins.contains(o) { v.origins.remove(o) } else { v.origins.insert(o) }
                    }
                }
            }
        case .status:
            RequestsFilterPills(title: "Status") {
                ForEach(HistoryFilter.allCases, id: \.self) { s in
                    option(s.title, on: nav.filter[pane].status == s) { $0.status = s }
                }
            }
        case .threadType:
            if nav.threadTypes {
                pills("Type", [("all", "All"), ("request", "Requests"), ("issue", "Issues")], \.threadType)
            }
        case .problem:
            pills("Type", [("all", "All")] + IssueFormat.problems.map { ($0.value, $0.label) }, \.problem)
        case .issueState:
            pills("State", [("open", "Open"), ("resolved", "Resolved"), ("all", "All")], \.issueState)
        case .range:
            RequestsFilterPills(title: "Range") {
                ForEach(InsightsRange.options, id: \.self) { w in
                    option(InsightsRange.label(w), on: nav.filter[pane].weeks == w) { $0.weeks = w }
                }
            }
        case .display:
            VStack(alignment: .leading, spacing: 8) {
                RequestsFilterLabel(text: "Display")
                Picker("Display", selection: $nav.inboxList) {
                    Text("Cards").tag(false)
                    Text("List").tag(true)
                }
                .pickerStyle(.segmented)
                Text("Remembered on this device.").font(.system(size: 12)).foregroundStyle(Theme.dim).padding(.leading, 4)
            }
        case .density:
            VStack(alignment: .leading, spacing: 8) {
                RequestsFilterLabel(text: "Card density")
                Picker("Card density", selection: $nav.filter[pane].compact) {
                    Text("Comfortable").tag(false)
                    Text("Compact").tag(true)
                }
                .pickerStyle(.segmented)
            }
        case .mineShow, .mineSource, .mineKind:
            MineFilterGroup(section: section)
        }
    }

    private func option(_ title: String, on: Bool, _ change: @escaping (inout RequestsFilter.Values) -> Void) -> some View {
        RequestsFilterOption(title: title, on: on) { change(&nav.filter[nav.pane]) }
    }

    private func pills(_ title: String, _ options: [(String, String)],
                       _ key: WritableKeyPath<RequestsFilter.Values, String>) -> some View {
        RequestsFilterPills(title: title) {
            ForEach(options, id: \.0) { o in
                option(o.1, on: nav.filter[nav.pane][keyPath: key] == o.0) { $0[keyPath: key] = o.0 }
            }
        }
    }
}
