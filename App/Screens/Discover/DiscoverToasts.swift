import SwiftUI
import UIKit
import WebKit
import FusionhaKit

// MARK: DiscoverToasts

enum DiscoverToastVariant { case success, info, error }

struct DiscoverToastMessage: Identifiable, Equatable {
    let id = UUID()
    let variant: DiscoverToastVariant
    let title: String?
    let message: String
}

/// The shared toast queue every Discover-side mutation reports through.
@MainActor
@Observable
final class DiscoverToasts {
    static let shared = DiscoverToasts()
    private(set) var current: DiscoverToastMessage?
    private var hide: Task<Void, Never>?

    /// The app's toasts (`AppModel.toast`, set by the shell): when present,
    /// every Discover toast goes there, so the app has one toast stack.
    var sink: (@MainActor (_ variant: DiscoverToastVariant, _ message: String, _ title: String?) -> Void)?

    func show(_ variant: DiscoverToastVariant, _ message: String, title: String? = nil) {
        if let sink {
            sink(variant, message, title)
            return
        }
        let toast = DiscoverToastMessage(variant: variant, title: title, message: message)
        current = toast
        hide?.cancel()
        hide = Task {
            try? await Task.sleep(for: .seconds(variant == .error ? 6 : 4))
            guard !Task.isCancelled else { return }
            if self.current == toast { self.current = nil }
        }
    }

    func error(_ title: String, _ error: Error) {
        show(.error, error.localizedDescription, title: title)
    }

    func dismiss() { current = nil }
}

struct DiscoverToastOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var bottomInset: CGFloat = 72

    func body(content: Content) -> some View {
        let toasts = DiscoverToasts.shared
        content.overlay(alignment: .bottom) {
            if let toast = toasts.current {
                DiscoverToastView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { toasts.dismiss() }
                    .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: toasts.current)
    }
}

extension View {
    func discoverToastOverlay(bottomInset: CGFloat = 72) -> some View {
        modifier(DiscoverToastOverlay(bottomInset: bottomInset))
    }
}

struct DiscoverToastView: View {
    let toast: DiscoverToastMessage

    private var color: Color {
        switch toast.variant {
        case .success: return Theme.done
        case .info: return Theme.grab
        case .error: return Theme.danger
        }
    }

    private var icon: String {
        switch toast.variant {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 15).padding(.trailing, 13).padding(.top, 13).padding(.bottom, 15)
        .frame(maxWidth: 420)
        .statusWash(color, base: Theme.panel.opacity(0.92), radius: Theme.radius)
        .shadow(color: Theme.shelfShadow.opacity(0.6), radius: 22, y: 18)
        .accessibilityElement(children: .combine)
    }
}
