import Foundation

/// Manual Import parts built ahead of the owner's approval. Not user-visible:
/// no setting, one line to turn on.
public enum ManualImportFeatures {
    /// "Bar in every scenario" (mock T6bWkYmLvaSBmbSMa2rw5m, not yet
    /// approved): the bulk bar on folder scans and not-held downloads too,
    /// Keep current with no disposition, and the "N selected · Actions" sheet
    /// gone. Off: only held downloads (the approved v3 mock) get the bar, and
    /// every other scan keeps the selection sheet as before.
    public static let barEverywhere = false

    /// The bulk bar replaces the selection sheet for this scan.
    public static func bulkBar(_ scan: ManualImportScan?, everywhere: Bool = barEverywhere) -> Bool {
        guard let scan else { return false }
        return everywhere || scan.isRescue
    }
}
