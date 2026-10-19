import SwiftUI
import FusionhaKit

/// The filters set on the current view, each removable, plus Clear. Nothing
/// shows when no filter is set (Final mock).
struct RequestsFilterChips: View {
    @Environment(RequestsNav.self) private var nav

    private struct Chip: Identifiable {
        let id: String
        let label: String
        let remove: (inout RequestsFilter.Values) -> Void
    }

    private var chips: [Chip] {
        let v = nav.filter[nav.pane]
        var out: [Chip] = []
        let q = v.search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { out.append(Chip(id: "q", label: "“\(q)”") { $0.search = "" }) }
        if let id = v.requesterId {
            let name = nav.people.first { $0.id == id }?.displayName ?? "Requester"
            out.append(Chip(id: "u", label: name) { $0.requesterId = nil })
        }
        if v.status != .all { out.append(Chip(id: "s", label: v.status.title) { $0.status = .all }) }
        if v.issueState != "open" {
            out.append(Chip(id: "i", label: v.issueState == "resolved" ? "Resolved" : "All states") { $0.issueState = "open" })
        }
        if v.threadType != "all" {
            out.append(Chip(id: "t", label: v.threadType == "issue" ? "Issues" : "Requests") { $0.threadType = "all" })
        }
        if v.mineIssues { out.append(Chip(id: "m", label: "My issues") { $0.mineIssues = false }) }
        if v.mineStatus != .active { out.append(Chip(id: "ms", label: v.mineStatus.title) { $0.mineStatus = .active }) }
        for o in RequestOrigin.allCases where v.origins.contains(o) {
            out.append(Chip(id: "o-\(o.rawValue)", label: o.title) { $0.origins.remove(o) })
        }
        return out
    }

    var body: some View {
        let chips = chips
        if !chips.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        HStack(spacing: 2) {
                            Text(chip.label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Button {
                                withAnimation(.snappy) { chip.remove(&nav.filter[nav.pane]) }
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(chip.label)")
                        }
                        .foregroundStyle(Theme.txt)
                        .padding(.leading, 12).padding(.trailing, 4)
                        .frame(height: 32)
                        .background(Theme.primary.opacity(0.22), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.primary.opacity(0.35)))
                    }
                    Button("Clear") { withAnimation(.snappy) { nav.filter.reset(nav.pane) } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 10).frame(height: 32)
                        .buttonStyle(.plain)
                }
            }
            .scrollIndicators(.hidden)
            .transition(.opacity)
        }
    }
}
