import SwiftUI
import FusionhaKit

// MARK: Empty state (`components/ui/EmptyState`)

struct CalEmptyState: View {
    let message: String
    var quip: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .lineSpacing(13.5 * 0.6 - 3)
            if let quip {
                (Text("— ").foregroundColor(Theme.txt.opacity(0.08)) + Text(quip).italic().foregroundColor(Theme.dim))
                    .font(.system(size: 13.5))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

// MARK: Toast

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
