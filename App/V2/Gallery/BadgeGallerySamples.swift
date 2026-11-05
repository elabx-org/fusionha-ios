import SwiftUI
import FusionhaKit

/// The states the Badge gallery shows: every single badge state, the pairs
/// that join and the pairs that sit apart, and the rails.
enum BadgeGallerySamples {
    struct Single: Identifiable {
        let label: String
        let state: EditionBadgeState
        var id: String { label }
    }

    struct Pair: Identifiable {
        let label: String
        let hd: EditionBadgeState?
        let uhd: EditionBadgeState?
        var id: String { label }
    }

    struct Season: Identifiable {
        let label: String
        let have: Int, aired: Int, total: Int
        let state: EditionBadgeState
        var id: String { label }
    }

    static let singles: [Single] = [
        Single(label: "On disk", state: .onDisk),
        Single(label: "Partly on disk", state: .partial(have: 3, of: 5)),
        Single(label: "Missing", state: .missing),
        Single(label: "Downloading 40%", state: .downloading(progress: 0.4)),
        Single(label: "Downloading, no figure yet", state: .downloading(progress: nil)),
        Single(label: "Held", state: .held),
    ]

    static let pairs: [Pair] = [
        Pair(label: "Both on disk (joined)", hd: .onDisk, uhd: .onDisk),
        Pair(label: "Both missing (joined)", hd: .missing, uhd: .missing),
        Pair(label: "HD on disk, 4K missing", hd: .onDisk, uhd: .missing),
        Pair(label: "HD on disk, 4K downloading", hd: .onDisk, uhd: .downloading(progress: 0.62)),
        Pair(label: "HD downloading, 4K missing", hd: .downloading(progress: 0.18), uhd: .missing),
        Pair(label: "HD partly, 4K held", hd: .partial(have: 6, of: 8), uhd: .held),
        Pair(label: "Both held", hd: .held, uhd: .held),
        Pair(label: "Both partly", hd: .partial(have: 6, of: 8), uhd: .partial(have: 2, of: 8)),
        Pair(label: "HD only", hd: .onDisk, uhd: nil),
        Pair(label: "4K only, held", hd: nil, uhd: .held),
    ]

    /// VisionQuest S1 in the mock: 8 episodes, 6 on disk, 7 aired.
    static let seasons: [Season] = [
        Season(label: "E7 missing", have: 6, aired: 7, total: 8, state: .partial(have: 6, of: 7)),
        Season(label: "E7 downloading", have: 6, aired: 7, total: 8, state: .downloading(progress: 0.62)),
        Season(label: "E7 held", have: 6, aired: 7, total: 8, state: .held),
        Season(label: "Complete", have: 8, aired: 8, total: 8, state: .onDisk),
        Season(label: "24 episodes", have: 20, aired: 22, total: 24, state: .partial(have: 20, of: 22)),
        Season(label: "Long season (capsule)", have: 30, aired: 34, total: 40, state: .partial(have: 30, of: 34)),
    ]

    static let storage: [StorageCapsule.Segment] = [
        .init(label: "Series HD", bytes: 148.5 * gb, shade: 0.86),
        .init(label: "Series 4K", bytes: 33.9 * gb, shade: 0.52),
        .init(label: "Movies HD", bytes: 67.6 * gb, shade: 0.70),
        .init(label: "Movies 4K", bytes: 54.0 * gb, shade: 0.40),
        .init(label: "Other", bytes: 193.3 * gb, shade: 0.28),
    ]
    static let storageCapacity = 1000.2 * gb

    private static let gb = 1_073_741_824.0

    /// The joined ⇄ apart demo: tapping steps through these.
    static let cycle: [(EditionBadgeState, EditionBadgeState)] = [
        (.onDisk, .onDisk),
        (.onDisk, .downloading(progress: 0.35)),
        (.onDisk, .held),
        (.missing, .missing),
    ]
}
