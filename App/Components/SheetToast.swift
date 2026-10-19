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

/// A bottom toast, like the web's `useToast`. Glass, since it is chrome.
struct CalToastHost: ViewModifier {
    @Binding var toast: CalToast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toast.isError ? Theme.danger : Theme.done)
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = toast.title {
                            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                        }
                        Text(toast.message).font(.system(size: 13)).foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(3.2))
                    withAnimation(.smooth) { self.toast = nil }
                }
                .onTapGesture { withAnimation(.smooth) { self.toast = nil } }
            }
        }
        .animation(.smooth(duration: 0.25), value: toast)
    }
}

extension View {
    func calToast(_ toast: Binding<CalToast?>) -> some View {
        modifier(CalToastHost(toast: toast))
    }
}
