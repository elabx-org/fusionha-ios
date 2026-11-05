import Foundation
import FusionhaKit

/// The answers to a held download (plan S8, held-decision-clarity). `stay` is
/// what happens without a choice: the download stays held and the button
/// opens it in Manual Import (where it can be imported, kept or skipped per
/// file). Every other answer is an override: it turns orange, renames the
/// button and asks once more before it runs. Fusionha's own pick is not
/// offered until the server states it (API gap 7).
enum HeldChoice: String, CaseIterable, Identifiable {
    case stay, removeSearch, removeBlocklist, removeOnly

    var id: String { rawValue }

    static let overrides: [HeldChoice] = [.removeSearch, .removeBlocklist, .removeOnly]

    var isOverride: Bool { self != .stay }

    var title: String {
        switch self {
        case .stay: return "It stays held until you choose"
        case .removeSearch: return "Remove it and search again"
        case .removeBlocklist: return "Remove and blocklist this release"
        case .removeOnly: return "Remove the download only"
        }
    }

    func detail(_ item: QueueItem) -> String {
        let data = item.hasDownloadedFile == true ? " and its downloaded data is deleted" : ""
        switch self {
        case .stay:
            return "Fusionha has not said what it would do with this hold yet. Nothing is imported or removed meanwhile; Manual Import lets you import, keep or skip each file."
        case .removeSearch:
            return "The download leaves the client\(data). Fusionha searches for another \(item.tier.badgeLetters) release."
        case .removeBlocklist:
            let who = item.parsed?.releaseGroup.map { "\($0)’s release" } ?? "This release"
            return "\(who) is never grabbed again for this title. Fusionha searches for another."
        case .removeOnly:
            return "The download leaves the client\(data). No search, no blocklist."
        }
    }

    /// The commit button's words and symbol.
    var goLabel: String {
        switch self {
        case .stay: return "Review in Manual Import"
        case .removeSearch: return "Remove download · search again"
        case .removeBlocklist: return "Remove · blocklist release"
        case .removeOnly: return "Remove download"
        }
    }

    var goIcon: String {
        switch self {
        case .stay: return "square.and.arrow.down"
        case .removeSearch: return "magnifyingglass"
        case .removeBlocklist: return "nosign"
        case .removeOnly: return "trash"
        }
    }

    /// The confirmation's question (overrides only).
    func confirmTitle(_ item: QueueItem) -> String {
        let name = [item.title, item.episodeLabel].compactMap { $0 }.joined(separator: " ")
        switch self {
        case .stay: return ""
        case .removeSearch: return "Remove \(name) and search again?"
        case .removeBlocklist: return "Remove and blocklist this release of \(name)?"
        case .removeOnly: return "Remove \(name) from the queue?"
        }
    }
}
