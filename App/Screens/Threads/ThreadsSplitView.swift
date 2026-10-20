import SwiftUI
import FusionhaKit

/// The wide Threads and Issues (web `ThreadsPanel`, `threads.module.css
/// .split`): the list on the leading side (390 wide, 290 at 960 and below)
/// and the selected thread's pane beside it, each scrolling on its own. The
/// first row is selected when nothing is (ruling R8); the phone keeps the
/// list and its sheets (DU5).
struct ThreadsSplitView: View {
    let items: [ThreadItem]
    let hasMore: Bool
    let onLoadMore: () -> Void
    /// A request thread changed (a decision, a reply): reload the list.
    let onChanged: () -> Void
    @Binding var selected: ThreadItem.ID?
    @Environment(AppModel.self) private var model

    private var current: ThreadItem? {
        items.first { $0.id == selected } ?? items.first
    }

    var body: some View {
        GeometryReader { proxy in
            let narrow = proxy.size.width + RequestsWideRule.margins <= 960
            HStack(alignment: .top, spacing: narrow ? 12 : 16) {
                list.frame(width: min(narrow ? 290 : 390, proxy.size.width * 0.45))
                pane.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items) { item in
                    let on = item.id == current?.id
                    Button { selected = item.id } label: { ThreadRowView(item: item) }
                        .buttonStyle(.plain)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(on ? Theme.i1.opacity(0.55) : .clear, lineWidth: 1.5))
                        .accessibilityAddTraits(on ? .isSelected : [])
                }
                if hasMore {
                    Button("Load more", action: onLoadMore).buttonStyle(.discover(.subtle))
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var pane: some View {
        if let item = current {
            Group {
                if item.type == "issue", let issue = item.issue {
                    VStack(spacing: 0) {
                        issueBar(issue)
                        IssuePaneView(seed: issue, linkedRequestId: item.linkedPendingRequestId)
                    }
                    .background(Theme.bg)
                } else if let request = item.request {
                    RequestThreadView(request: request, onChanged: onChanged)
                        .background(Theme.bg)
                }
            }
            .id(item.id)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        }
    }

    /// The pane's head (web `PaneHeader`): Open in library, as the sheet's bar has.
    private func issueBar(_ issue: MediaIssue) -> some View {
        HStack {
            Spacer()
            Button("Open in library", systemImage: "arrow.up.right.square") { model.open(issue.mediaItemId) }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.glass)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }
}
