import Foundation
import FusionhaKit

/// One streaming service (or studio) in the library: the `network_name` the
/// server sends on each library row (0.4.238), its logo, and how many
/// titles carry it.
struct V2LibraryService: Identifiable, Hashable {
    let name: String
    let logoUrl: String?
    let count: Int

    var id: String { name }
    var studio: Studio { Studio(name: name, logoUrl: logoUrl) }
}

enum V2LibraryServices {
    /// The menu's cap: a big library names a long tail of studios; the
    /// services most of the library sits on come first.
    static let limit = 12

    /// The library's services, most titles first, then A–Z; at most `limit`,
    /// plus `keeping` (the picked one) when it falls outside them. Empty on
    /// a server older than 0.4.238 (no row carries a network).
    static func from(_ library: [MediaItem], keeping picked: String = "") -> [V2LibraryService] {
        var counts: [String: Int] = [:]
        var logos: [String: String] = [:]
        for item in library {
            guard let name = item.networkName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            counts[name, default: 0] += 1
            if logos[name] == nil, let logo = item.networkLogoUrl, !logo.isEmpty { logos[name] = logo }
        }
        let all = counts.map { V2LibraryService(name: $0.key, logoUrl: logos[$0.key], count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var top = Array(all.prefix(limit))
        if !picked.isEmpty, !top.contains(where: { $0.name == picked }),
           let kept = all.first(where: { $0.name == picked }) {
            top.append(kept)
        }
        return top
    }

    /// The titles on one service; all of them when none is picked.
    static func narrow(_ library: [MediaItem], to network: String) -> [MediaItem] {
        guard !network.isEmpty else { return library }
        return library.filter { $0.networkName?.trimmingCharacters(in: .whitespaces) == network }
    }
}
