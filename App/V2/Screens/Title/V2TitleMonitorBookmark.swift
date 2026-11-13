import SwiftUI
import FusionhaKit

/// Monitor as a bookmark right after the title (owner approved the mock,
/// 2026-11-13; it replaces the action row's Monitored button). Filled in the
/// title's ink = monitored, thin outline = not; no colour either way. A tap
/// flips it at once: turning it off says "Stopped monitoring" with Undo,
/// turning it on says "Monitoring again". No confirm dialog: Undo is the
/// safety net. 44pt to tap whatever the glyph's size.
struct V2TitleMonitorBookmark: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    /// The title's point size: the glyph follows it.
    var size: CGFloat
    /// The flip while the PATCH is in flight.
    @State private var monitorOverride: Bool?

    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var monitored: Bool { monitorOverride ?? (detail.monitored ?? true) }

    var body: some View {
        Button { set(!monitored) } label: {
            Text(Image(systemName: monitored ? "bookmark.fill" : "bookmark"))
                .font(.system(size: size * 0.6, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
        // The 44pt target overhangs the title's line instead of spacing it out.
        .padding(.vertical, -max(0, (44 - size) / 2))
        .sensoryFeedback(.selection, trigger: monitored)
        .onChange(of: detail.monitored) { monitorOverride = nil }
        .accessibilityLabel(monitored ? "Monitored" : "Not monitored")
        .accessibilityHint(canEdit ? (monitored ? "Stops monitoring" : "Starts monitoring") : "")
    }

    /// The Library's bulk monitor for this one title, then the page reloads.
    private func set(_ next: Bool) {
        monitorOverride = next
        let override = $monitorOverride
        let title = detail.title
        let itemId = detail.id
        Task {
            do {
                try await store.client?.bulkMonitor(BulkMonitorRequest(itemIds: [itemId], monitored: next))
                if next {
                    store.show("Monitoring \(title) again", variant: .success)
                } else {
                    store.show("Stopped monitoring \(title)", variant: .info, actionLabel: "Undo") {
                        override.wrappedValue = true
                        Task { await Self.undo(store: store, model: model, itemId: itemId, title: title, override: override) }
                    }
                }
                await store.reload()
                await model.loadLibrary()
            } catch {
                monitorOverride = nil
                store.show("Couldn't update \(title)", variant: .error)
            }
        }
    }

    private static func undo(store: DetailStore, model: AppModel, itemId: Int, title: String,
                             override: Binding<Bool?>) async {
        do {
            try await store.client?.bulkMonitor(BulkMonitorRequest(itemIds: [itemId], monitored: true))
            store.show("Monitoring \(title) again", variant: .success)
            await store.reload()
            await model.loadLibrary()
        } catch {
            override.wrappedValue = nil
            store.show("Couldn't update \(title)", variant: .error)
        }
    }
}

/// The title followed by its bookmark: on a two-line title the bookmark sits
/// on the last line.
struct V2TitleWithBookmark<Title: View>: View {
    let detail: ItemDetail
    let size: CGFloat
    @ViewBuilder let title: Title

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            title
            V2TitleMonitorBookmark(detail: detail, size: size)
        }
    }
}
