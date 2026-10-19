import SwiftUI
import FusionhaKit

// `fusionha://activity/queue?focus=<download_id>` (web `use-queue-deep-link.ts`):
// scroll the download's card into view, open its group, and flash it once.

enum QueueFocus {
    /// The scroll id of an Up next slot.
    static func upNextId(_ downloadId: Int) -> String { "up:\(downloadId)" }

    /// How long the focused card stays highlighted.
    static let flashDuration: Duration = .seconds(1.8)
}

extension QueueLogic.Entry {
    /// Whether this card holds the download.
    func contains(_ downloadId: Int?) -> Bool {
        guard let downloadId else { return false }
        switch self {
        case .solo(let item, _): return item.id == downloadId
        case .group(let group, _): return group.downloads.contains { $0.id == downloadId }
        }
    }
}

extension ActivityQueueTab {
    /// Takes a pending `?focus=` once its download is loaded: opens what hides
    /// it (a collapsed group, the folded Up next tail), scrolls to it, flashes it.
    func bringFocusForward(_ proxy: ScrollViewProxy) {
        guard let id = model.pendingQueueScroll, store.loaded else { return }
        guard let item = store.items.first(where: { $0.id == id }) else {
            // Not in the loaded queue (finished, or on a later page): a quiet no-op.
            model.pendingQueueScroll = nil
            return
        }
        model.pendingQueueScroll = nil
        let section = QueueSection.of(item)
        let target: String
        if section == .upnext {
            upNextOpen = true
            target = QueueFocus.upNextId(id)
        } else {
            let list = store.items.filter { QueueSection.of($0) == section }
            let entry = QueueLogic.entries(list, section: section, telemetry: store.telemetry).first { $0.contains(id) }
            if case .group(let group, _) = entry, !group.isPair { QueueGroupMemory.set(group.id, open: true) }
            target = entry?.id ?? ""
        }
        focusId = id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            if reduce {
                proxy.scrollTo(target, anchor: .center)
            } else {
                withAnimation(.snappy(duration: 0.4)) { proxy.scrollTo(target, anchor: .center) }
            }
            try? await Task.sleep(for: QueueFocus.flashDuration)
            if focusId == id { focusId = nil }
        }
    }
}

extension View {
    /// The focus flash: an accent ring that fades in and out (instant under Reduce Motion).
    func queueFlash(_ on: Bool, reduce: Bool, radius: CGFloat = 16) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.primary, lineWidth: 2)
                .opacity(on ? 1 : 0)
                .animation(reduce ? nil : .easeInOut(duration: 0.35), value: on)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
