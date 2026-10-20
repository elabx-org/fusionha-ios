import SwiftUI
import FusionhaKit

/// One tier's form state before it becomes a `VersionCreate` (`TierState`).
struct AddTierState: Equatable {
    /// On → this version is added and monitored; off → not added at all.
    var on: Bool
    var rootId: Int
    var profileId: Int
    /// This tier's series monitor level; differs from the master only as an override.
    var monitor: String
}

/// A failed add, typed for where it shows: a 409 folder collision on the Folder
/// row, anything else in the footer.
struct AddFlowError: Equatable {
    let folder: Bool
    let message: String
}
