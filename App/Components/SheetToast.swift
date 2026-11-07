import SwiftUI

// MARK: Sheet toast

/// A toast inside a sheet (Sign-in methods, Move credential, User access,
/// Notifications), where the shell's `ToastHost` sits behind the sheet. Pages
/// under the shell use `AppModel.toast` instead.
struct CalToast: Equatable, Identifiable {
    let id = UUID()
    var title: String?
    let message: String
    var isError = false
}

/// The sheet's toast, at the top of the sheet: the app's one glass toast.
struct CalToastHost: ViewModifier {
    @Binding var toast: CalToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast {
                GlassToastView(symbol: toast.isError ? GlassToastSymbol.error : GlassToastSymbol.success,
                               tint: toast.isError ? Theme.danger : Theme.done,
                               title: toast.title, message: toast.message,
                               dismiss: { withAnimation(reduceMotion ? nil : .smooth) { self.toast = nil } })
                .padding(.top, 12)
                .transition(.glassToast(reduceMotion: reduceMotion))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(3.2))
                    guard !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .smooth) { self.toast = nil }
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: toast)
    }
}

extension View {
    func calToast(_ toast: Binding<CalToast?>) -> some View {
        modifier(CalToastHost(toast: toast))
    }
}
