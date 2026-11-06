import Foundation
import FusionhaKit

/// Interactive search rows of a blocked group (web 0.4.239): they flip to
/// rejected ("Blocked group") and stay visible even with Hide rejected on.
@MainActor
enum V2SearchGroupBlocks {
    /// Where the row's group is blocked: the loaded blocks, or the server's
    /// own rejection ("Release group X is blocked everywhere").
    static func label(_ release: ReleasePreview, store: DetailStore) -> String? {
        if let block = store.groupBlock(for: release.releaseGroup) { return TitleGroupBlocks.scopeLabel(block) }
        guard release.rejected, TitleGroupBlocks.isGroupBlockReason(release.reason) else { return nil }
        return release.reason?.lowercased().hasSuffix("everywhere") == true ? "Everywhere" : "This title"
    }

    /// The filters' rows in their order, plus the blocked-group rows Hide
    /// rejected would drop.
    static func visible(_ rows: [ReleasePreview], filters: ReleaseFilters, store: DetailStore) -> [ReleasePreview] {
        guard filters.hideRejected, store.groupBlocks?.isEmpty == false else { return filters.apply(rows) }
        var relaxed = filters
        relaxed.hideRejected = false
        let kept = Set(filters.apply(rows).map(\.guid))
        return relaxed.apply(rows).filter { kept.contains($0.guid) || store.groupBlock(for: $0.releaseGroup) != nil }
    }

    /// "Release group NTb is blocked for this title." for the Grab anyway sheet.
    static func problem(_ release: ReleasePreview, label: String) -> String {
        let group = release.releaseGroup ?? "of this release"
        return "Release group \(group) is blocked \(label == "Everywhere" ? "everywhere" : "for this title")."
    }
}
