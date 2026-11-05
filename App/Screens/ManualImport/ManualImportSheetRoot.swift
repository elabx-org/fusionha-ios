import SwiftUI
import FusionhaKit

extension EnvironmentValues {
    /// A replacement for the Manual Import sheet. v1 never sets it, so the
    /// sheet is `ManualImportSheet`; v2 (`V2RootView`) passes its grouped
    /// Manual Import here.
    @Entry var manualImportSheet: ManualImportSheetOverride?
}

/// The view a product shows for a Manual Import request: the held download
/// ids (empty for a folder scan), the client, and the web fallback.
struct ManualImportSheetOverride {
    let make: @MainActor (_ downloadIds: [Int], _ client: APIClient?, _ onOpenWeb: @escaping () -> Void) -> AnyView
}

/// The Manual Import sheet: the override when one is set, else v1's sheet.
struct ManualImportSheetRoot: View {
    let downloadIds: [Int]
    let client: APIClient?
    let onOpenWeb: () -> Void
    @Environment(\.manualImportSheet) private var override

    var body: some View {
        if let override {
            override.make(downloadIds, client, onOpenWeb)
        } else {
            ManualImportSheet(downloadIds: downloadIds, client: client, onOpenWeb: onOpenWeb)
        }
    }
}
