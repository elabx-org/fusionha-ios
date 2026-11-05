import SwiftUI
import FusionhaKit

/// The one place v2 decides which version the open tab shows, so the version
/// cards' ring and the series Files tab can't drift apart.
extension DetailStore {
    /// The open tab can show every version at once. A series' Files tab
    /// can't: it lists one version's episodes.
    var v2TabShowsAllVersions: Bool { !(tab == .files && detail?.isSeries == true) }

    /// The version the open tab shows: the selected one, else (a tab with no
    /// all-versions view) the first ordered edition; nil for all versions.
    var v2ShownVersion: DetailEdition? {
        focusedVersion ?? (v2TabShowsAllVersions ? nil : detail?.orderedEditions.first)
    }
}
