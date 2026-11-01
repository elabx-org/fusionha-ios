import Foundation

/// Manual Import switches. Not user-visible: no setting, one line to change.
public enum ManualImportFeatures {
    /// "Bar in every scenario" (mock T6bWkYmLvaSBmbSMa2rw5m, owner-approved
    /// 2026-11-01): the bulk bar on folder scans and not-held downloads too,
    /// Keep current there a single action with no disposition ("Keep current
    /// for N · nothing imported, your library file stays"), and the
    /// "N selected · Actions" sheet gone. Off: only held downloads get the bar,
    /// and every other scan keeps the selection sheet.
    public static let barEverywhere = true

    /// The bulk bar replaces the selection sheet for this scan.
    public static func bulkBar(_ scan: ManualImportScan?, everywhere: Bool = barEverywhere) -> Bool {
        guard let scan else { return false }
        return everywhere || scan.isRescue
    }
}
