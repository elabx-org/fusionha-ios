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

/// Discover's own toasts when no shell sink is set, at the top of the page.
struct DiscoverToastOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let toasts = DiscoverToasts.shared
        content.overlay(alignment: .top) {
            if let toast = toasts.current {
                DiscoverToastView(toast: toast) { toasts.dismiss() }
                    .padding(.top, 8)
                    .transition(.glassToast(reduceMotion: reduceMotion))
                    .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: toasts.current)
    }
}

extension View {
    func discoverToastOverlay() -> some View {
        modifier(DiscoverToastOverlay())
    }
}

/// A Discover toast: the app's one glass toast.
struct DiscoverToastView: View {
    let toast: DiscoverToastMessage
    let dismiss: () -> Void

    private var color: Color {
        switch toast.variant {
        case .success: return Theme.done
        case .info: return Theme.grab
        case .error: return Theme.danger
        }
    }

    private var icon: String {
        switch toast.variant {
        case .success: return GlassToastSymbol.success
        case .info: return GlassToastSymbol.info
        case .error: return GlassToastSymbol.error
        }
    }

    var body: some View {
        GlassToastView(symbol: icon, tint: color, title: toast.title, message: toast.message, dismiss: dismiss)
    }
}
