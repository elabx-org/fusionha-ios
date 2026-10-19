import SwiftUI
import FusionhaKit

/// The filter sheet (Final mock): Reset and a close button in the bar, the
/// view's sections, and one button that counts the result and closes. Every
/// choice applies as it is tapped.
struct RequestsFilterSheet: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(\.dismiss) private var dismiss

    private var sections: Set<RequestsFilter.Section> { nav.pane.filters }

    var body: some View {
        @Bindable var nav = nav
        let pane = nav.pane
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if sections.contains(.search) {
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
                    }
                    if sections.contains(.status) {
                        group("Status") {
                            ForEach(HistoryFilter.allCases, id: \.self) { s in
                                option(s.title, on: nav.filter[pane].status == s) { nav.filter[pane].status = s }
                            }
                        }
                    }
                    if sections.contains(.issueState) {
                        group("State") {
                            ForEach([("open", "Open"), ("resolved", "Resolved"), ("all", "All")], id: \.0) { s in
                                option(s.1, on: nav.filter[pane].issueState == s.0) { nav.filter[pane].issueState = s.0 }
                            }
                        }
                    }
                    if sections.contains(.requester) {
                        group("Requester") {
                            option("Anyone", on: nav.filter[pane].requesterId == nil) { nav.filter[pane].requesterId = nil }
                            ForEach(nav.people, id: \.id) { p in
                                option(p.displayName, on: nav.filter[pane].requesterId == p.id) { nav.filter[pane].requesterId = p.id }
                            }
                        }
                    }
                    if sections.contains(.source) {
                        group("Source") {
                            ForEach(RequestOrigin.allCases, id: \.self) { o in
                                option(o.title, on: nav.filter[pane].origins.contains(o)) {
                                    if nav.filter[pane].origins.contains(o) { nav.filter[pane].origins.remove(o) } else { nav.filter[pane].origins.insert(o) }
                                }
                            }
                        }
                    }
                    if sections.contains(.display) {
                        VStack(alignment: .leading, spacing: 8) {
                            label("Display")
                            Picker("Display", selection: $nav.inboxList) {
                                Text("Cards").tag(false)
                                Text("List").tag(true)
                            }
                            .pickerStyle(.segmented)
                            Text("Remembered on this device.").font(.system(size: 12)).foregroundStyle(Theme.dim).padding(.leading, 4)
                        }
                    }
                    if sections.contains(.density) {
                        VStack(alignment: .leading, spacing: 8) {
                            label("Card density")
                            Picker("Card density", selection: $nav.filter[pane].compact) {
                                Text("Comfortable").tag(false)
                                Text("Compact").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text(resultLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(Theme.panel)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { withAnimation(.snappy) { nav.filter.reset(pane) } }
                        .disabled(nav.filter.activeCount(pane) == 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .sensoryFeedback(.selection, trigger: nav.filter)
    }

    /// "Show 9 requests" once the view has counted, else "Show results".
    private var resultLabel: String {
        guard let n = nav.resultCount else { return "Show results" }
        let noun = nav.pane == .history ? (n == 1 ? "decision" : "decisions")
            : nav.pane == .issues ? (n == 1 ? "issue" : "issues") : (n == 1 ? "request" : "requests")
        return "Show \(n) \(noun)"
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut).padding(.leading, 4)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            ActFlow(spacing: 8, lineSpacing: 0) { content() }
        }
    }

    private func option(_ title: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(on ? Theme.primary.opacity(0.22) : Theme.panel2, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Theme.primary.opacity(0.7) : Theme.line, lineWidth: on ? 1.5 : 1))
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
