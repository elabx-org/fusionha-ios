import Foundation
import FusionhaKit

/// Opens an item's detail sheet from any screen.
struct ItemRef: Identifiable, Hashable {
    let id: Int
}

/// What the item detail should do once it opens, mirroring the web's
/// `/library/{id}?search={tier}` and `?edit=1` deep links. The detail screen
/// reads and clears `AppModel.detailIntent`.
enum DetailIntent: Hashable {
    case interactiveSearch(QualityTier?)
    case edit
    /// The Library poster sheet's drilled-in interactive search (season / episode / version).
    case scopedSearch(ScopedSearch)
}

/// An interactive search scoped from the poster sheet: the version tabs (the
/// first is selected), an optional season or episode, and the sheet subtitle.
struct ScopedSearch: Hashable {
    var editionIds: [Int]
    var episodeId: Int?
    var seasonNumber: Int?
    var subtitle: String
}

/// A title waiting for the Delete confirmation (DeleteItemDialog).
struct DeleteTarget: Identifiable, Hashable {
    let id: Int
    let title: String
}

// MARK: - The open title across fold / unfold

/// The open title is a sheet when folded and the shell's trailing column when
/// unfolded. Both hosts show the same `DetailStore`, kept here while the title
/// stays open, so moving between them keeps the page's scope, tab and scroll,
/// any child sheet that was up and its draft (`DetailContinuity` in FusionhaKit).
extension AppModel {
    /// The open title's store, shared by whichever host shows it. Not observed:
    /// it is read from view bodies and changes only with `presentedItem`.
    func detailStore(for id: Int) -> DetailStore {
        detailSlot.value(for: id) { DetailStore(itemId: id) }
    }

    /// Called with every shell geometry change, before the hosts swap, so the
    /// leaving host's teardown cannot close the sheets the arriving host
    /// re-presents.
    func updateDetailHost(splitsWithTitle: Bool) {
        detailGate.update(splitsWithTitle: splitsWithTitle)
    }

    func detailHostAccepts(_ host: DetailHost) -> Bool {
        detailGate.accepts(host)
    }
}
