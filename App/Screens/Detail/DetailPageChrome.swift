import SwiftUI
import FusionhaKit

/// What surrounds the title page in either layout (the single column or the
/// open Duo's split, `DetailSpreadBody`): the toast, the art-tinted ground and
/// the bar, clear over the art, taking the title once the hero has scrolled
/// away (the old compact bar).
struct DetailPageChrome: ViewModifier {
    let store: DetailStore
    /// The hero has scrolled away (single column only).
    let compact: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) { toast }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: compact)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: store.toast)
            .background { AmbientBackdrop(url: store.detail.flatMap { $0.backdropUrl ?? $0.posterUrl }) }
            .navigationTitle(compact ? (store.detail?.title ?? "") : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(compact ? .visible : .hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = store.toast {
            DetailToastView(toast: toast) { store.toast = nil }
                .padding(.top, 8)
                .transition(.glassToast(reduceMotion: reduceMotion))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(toast.action == nil ? 3.5 : 6))
                    if store.toast?.id == toast.id { store.toast = nil }
                }
        }
    }
}
