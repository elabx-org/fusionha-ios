import SwiftUI
import FusionhaKit

// The queue's iPhone Duo split (web `queue/duo/use-queue-duo.ts`, ruling A2):
// on a split-capable pane still in the phone layout (`QueueDuoRule`, the inner
// display in portrait), a tapped single card or 4K + HD pair opens as a
// trailing column beside the list instead of opening the title. Groups keep
// opening in place. Above 720 (the desktop layout) cards open the title.

/// One open card: the entry and the section it sits in. Nil once it has left
/// the queue, so the column closes by itself (`findEntry`).
struct QueueDuoOpen {
    let entry: QueueLogic.Entry
    let section: QueueSection

    /// The open card's lead download (a pair's first version).
    var lead: QueueItem {
        switch entry {
        case .solo(let item, _): return item
        case .group(let group, _): return group.downloads[0]
        }
    }

    /// The card with this key in the current queue.
    static func find(_ key: String?, items: [QueueItem], telemetry: [Int: QueueTelemetry]) -> QueueDuoOpen? {
        guard let key else { return nil }
        let routed = Dictionary(grouping: items, by: QueueSection.of)
        for section in QueueSection.cardSections {
            let entries = QueueLogic.entries(routed[section] ?? [], section: section, telemetry: telemetry)
            if let entry = entries.first(where: { $0.id == key }) { return QueueDuoOpen(entry: entry, section: section) }
        }
        return nil
    }

    /// The key of the openable card holding this download: its single card or
    /// its 4K + HD pair. Groups are not openable (as on the web).
    static func key(for item: QueueItem, items: [QueueItem], telemetry: [Int: QueueTelemetry]) -> String? {
        let section = QueueSection.of(item)
        let peers = items.filter { QueueSection.of($0) == section }
        for entry in QueueLogic.entries(peers, section: section, telemetry: telemetry) {
            switch entry {
            case .solo(let solo, _) where solo.id == item.id: return entry.id
            case .group(let group, _) where group.isPair && group.downloads.contains(where: { $0.id == item.id }):
                return entry.id
            default: continue
            }
        }
        return nil
    }
}

/// Opens a card beside the list, when the queue is split. Cards call it from
/// their poster and title (which open the title otherwise).
struct QueueCardOpener {
    let open: (QueueItem) -> Bool
}

private struct QueueCardOpenerKey: EnvironmentKey {
    static let defaultValue: QueueCardOpener? = nil
}

extension EnvironmentValues {
    var queueCardOpener: QueueCardOpener? {
        get { self[QueueCardOpenerKey.self] }
        set { self[QueueCardOpenerKey.self] = newValue }
    }
}

extension AppModel {
    /// A card's poster or title: beside the list when the queue is split,
    /// otherwise the title (detail sheet or column).
    func openQueueCard(_ item: QueueItem, opener: QueueCardOpener?) {
        if opener?.open(item) == true { return }
        open(item.mediaItemId)
    }
}

extension View {
    /// The card open in the trailing column: a ring, never a border or a bar.
    func queueDuoSelected(_ on: Bool, radius: CGFloat = 16) -> some View {
        overlay {
            if on {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.i2.opacity(0.7), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
