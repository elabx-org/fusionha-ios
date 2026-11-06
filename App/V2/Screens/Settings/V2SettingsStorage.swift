import Foundation
import FusionhaKit

/// The server card's storage (mock settings-v2.js `cap` + `legend`): what
/// the HD and 4K versions take, what else sits on the library disks, and
/// what's free. Disks come from the root folders, counted once each (roots
/// on one disk report the same total and free space).
struct V2SettingsStorage {
    let hd: Double
    let uhd: Double
    let other: Double
    let free: Double
    let capacity: Double

    init?(roots: [RootFolderInfo]?, library: [MediaItem]) {
        guard let roots else { return nil }
        var seen = Set<String>()
        var capacity = 0.0, free = 0.0
        for root in roots {
            guard let total = root.totalSpace, total > 0 else { continue }
            let disk = "\(total)-\(root.freeSpace ?? 0)"
            guard seen.insert(disk).inserted else { continue }
            capacity += Double(total)
            free += Double(root.freeSpace ?? 0)
        }
        guard capacity > 0 else { return nil }
        var hd = 0.0, uhd = 0.0
        for item in library {
            for edition in item.editions {
                let size = edition.size ?? 0
                if edition.tier == .uhd { uhd += size } else { hd += size }
            }
        }
        let used = max(0, capacity - free)
        self.hd = hd
        self.uhd = uhd
        self.other = max(0, used - hd - uhd)
        self.free = free
        self.capacity = capacity
    }

    /// One ink in three shades (A1 monochrome, the badge gallery's).
    var segments: [StorageCapsule.Segment] {
        [.init(label: "HD", bytes: hd, shade: 0.86),
         .init(label: "4K", bytes: uhd, shade: 0.52),
         .init(label: "Other", bytes: other, shade: 0.35)]
    }
}
