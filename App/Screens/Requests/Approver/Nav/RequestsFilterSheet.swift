import SwiftUI
import FusionhaKit

/// The filter sheet (web `FilterSheet`): Reset and a close button in the bar,
/// the view's groups in the web's order, and one accent button that reads the
/// live result ("Show 9 requests", "Done" when the view has no figure) and
/// closes. Every choice applies as it is tapped.
struct RequestsFilterSheet: View {
    @Environment(RequestsNav.self) private var nav
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pane = nav.pane
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(pane.filters, id: \.self) { section in
                        RequestsFilterGroup(section: section)
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text(nav.resultLabel ?? RequestsResultLabel.fallback)
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
                    Button("Reset", systemImage: "arrow.counterclockwise") { withAnimation(.snappy) { nav.filter.reset(pane) } }
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
}

/// A group's small heading ("Requester").
struct RequestsFilterLabel: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut).padding(.leading, 4)
    }
}

/// One filter pill: an accent-ghost fill when on, with an optional count.
struct RequestsFilterOption: View {
    let title: String
    var count: Int? = nil
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                if let count {
                    Text(verbatim: "\(count)").font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.mut)
                }
            }
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

/// A labelled row of pills.
struct RequestsFilterPills<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RequestsFilterLabel(text: title)
            ActFlow(spacing: 8, lineSpacing: 0) { content() }
        }
    }
}
