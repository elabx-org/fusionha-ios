import SwiftUI
import FusionhaKit

/// The bindings one host (the sheet or the shell's column) presents the
/// detail's child sheets with. The flags live in `DetailStore`; a host reads
/// them only once it is ready (a re-host waits for the old host to leave) and
/// writes them only while the shell says it is the active host, so the leaving
/// host's teardown never closes what the arriving host re-presents.
@MainActor
struct DetailPresenter {
    let store: DetailStore
    let ready: Bool
    let accepts: () -> Bool

    func item<T>(_ keyPath: ReferenceWritableKeyPath<DetailStore, T?>) -> Binding<T?> {
        Binding(
            get: { ready ? store[keyPath: keyPath] : nil },
            set: { if accepts() { store[keyPath: keyPath] = $0 } }
        )
    }

    func flag(_ keyPath: ReferenceWritableKeyPath<DetailStore, Bool>) -> Binding<Bool> {
        Binding(
            get: { ready && store[keyPath: keyPath] },
            set: { if accepts() { store[keyPath: keyPath] = $0 } }
        )
    }
}

/// Keeps one field of a child sheet's draft in the open title's store while
/// the sheet moves between hosts (fold / unfold / rotation): saved when the
/// sheet goes away, restored when it comes back. Opening the sheet afresh
/// clears it (`DetailStore`). Outside a title (no store) it does nothing.
/// Attach it to the sheet's outermost view, never to a pushed page.
private struct RetainedDraft<Value>: ViewModifier {
    @Environment(DetailStore.self) private var store: DetailStore?
    let key: String
    @Binding var value: Value

    func body(content: Content) -> some View {
        content
            .onAppear {
                if let saved = store?.drafts.value(key, as: Value.self) { value = saved }
            }
            .onDisappear { store?.drafts.save(value, for: key) }
    }
}

extension View {
    /// `key` is `"<sheet>.<field>"`, the sheet named as in `DetailStore`'s flags.
    func retainsDraft<Value>(_ key: String, _ value: Binding<Value>) -> some View {
        modifier(RetainedDraft(key: key, value: value))
    }
}
