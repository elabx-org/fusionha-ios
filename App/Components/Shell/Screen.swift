import SwiftUI
import FusionhaKit

/// Wraps a tab's content in the page background. The title, the Account item
/// and the page's actions are in the system bar (`.shellPage(_:)`); where the
/// web shows its mobile "+" it is `AddTitleToolbarItem` there.
struct Screen<Content: View>: View {
    @Environment(AppModel.self) private var model
    /// Kept for source compatibility: pages that add place `AddTitleToolbarItem`.
    var showsAdd = false
    /// Kept for source compatibility: Library filters in place through the
    /// top-bar pill, every other tab opens the omni search.
    var filtersInPlace = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .top) {
                if !model.requestScoped { SetupProgressPill(barHeight: 0) }
            }
            .webBackground()
    }
}

/// The "+" of Library, Discover and Wanted as a toolbar item (D1; it replaced
/// the title row's glass "+"). Opens the Add sheet. Absent for request-scoped
/// sessions, without the add capability, and while selecting.
struct AddTitleToolbarItem: ToolbarContent {
    let model: AppModel

    var body: some ToolbarContent {
        if !model.requestScoped && model.me?.can("add") != false && !model.selectMode {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { model.openAddSearch() }
            }
            .barPriority(true)
        }
    }
}
