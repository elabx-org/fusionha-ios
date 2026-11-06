import SwiftUI
import FusionhaKit

/// The flat open Duo's sidebar (plan S14, mock minimize.js option A): every
/// section with its count, the Library's kinds under it, Activity's needs-you
/// count in orange, a Needs you list and the account at the foot, on
/// floating glass. The toggle at its top hides it (option B: the column's
/// tabs come back, minimized on scroll). `ShellSidebarHost` places it.
struct ShellSidebar: View {
    @Environment(AppModel.self) private var model
    let toggle: ShellSidebarToggle
    @State private var needs: [QueueItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sections
                    if !needs.isEmpty { ShellSidebarNeeds(items: needs) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            ShellSidebarAccount()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onQueueChange(model, initial: true) { [needs = $needs] queue in
            let next = queue.filter { QueueSection.of($0) == .needs }
            if next.map(\.id) != needs.wrappedValue.map(\.id) { needs.wrappedValue = next }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar")
    }

    private var header: some View {
        HStack {
            Text("fusionha")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.txt)
            Spacer(minLength: 0)
            Button("Hide sidebar", systemImage: "sidebar.left") { toggle.toggle() }
                .labelStyle(.iconOnly)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.txt.opacity(0.75))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var sections: some View {
        ShellSidebarRow(icon: "nav-library", title: "Library", on: model.tab == .library) { model.tab = .library }
        if model.tab == .library { ShellSidebarKinds() }
        ShellSidebarRow(icon: "nav-discover", title: "Discover", on: model.tab == .discover) { model.tab = .discover }
        ShellSidebarRow(icon: "nav-calendar", title: "Calendar", on: model.tab == .calendar) { model.tab = .calendar }
        ShellSidebarRow(icon: "nav-activity", title: "Activity", on: model.tab == .activity,
                        count: needs.count, countNeedsYou: true) { model.tab = .activity }
        ShellSidebarRow(icon: "nav-requests", title: "Requests", on: false, count: model.requestsBadge) {
            model.pendingDiscoverTab = .requests
            model.tab = .discover
        }
        if model.me?.isAdmin == true {
            ShellSidebarRow(symbol: "gearshape", title: "Settings", on: false) { model.avatar.showingSettings = true }
        }
    }
}
