import SwiftUI
import FusionhaKit

/// The item actions rail's sheets (ItemDetail.tsx `modals`): Rename files,
/// Edition aliases, Fix episode numbering and Report an issue.
struct DetailActionSheets: ViewModifier {
    @Bindable var store: DetailStore

    func body(content: Content) -> some View {
        content
            .sheet(item: $store.renameScope) { scope in
                if let detail = store.detail {
                    RenameSheet(title: detail.title, scope: scope)
                        .environment(store)
                }
            }
            .sheet(isPresented: $store.showingAliases) {
                if let detail = store.detail {
                    EditionAliasesSheet(detail: detail)
                        .environment(store)
                }
            }
            .sheet(isPresented: $store.showingNumbering) {
                if let detail = store.detail {
                    NumberingFixSheet(detail: detail)
                        .environment(store)
                }
            }
            .sheet(isPresented: $store.showingIssue) {
                if let detail = store.detail {
                    IssueModal(mediaItemId: detail.id, title: detail.title, isSeries: detail.isSeries,
                               seasons: store.issueSeasons) { [store] message, failed in
                        store.show(message, variant: failed ? .error : .success)
                    }
                }
            }
    }
}

extension View {
    func detailActionSheets(_ store: DetailStore) -> some View {
        modifier(DetailActionSheets(store: store))
    }
}
