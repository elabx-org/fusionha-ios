import SwiftUI

// MARK: - Toast

struct DetailToast: Identifiable, Equatable {
    enum Variant { case success, info, warning, error }
    let id = UUID()
    var title: String?
    var message: String
    var variant: Variant = .info
    var actionLabel: String?
    var action: (() -> Void)?

    static func == (a: DetailToast, b: DetailToast) -> Bool { a.id == b.id }

    var color: Color {
        switch variant {
        case .success: return Theme.done
        case .info: return Theme.i2
        case .warning: return Theme.miss
        case .error: return Theme.danger
        }
    }

    var symbol: String {
        switch variant {
        case .success: return GlassToastSymbol.success
        case .info: return GlassToastSymbol.info
        case .warning: return GlassToastSymbol.warning
        case .error: return GlassToastSymbol.error
        }
    }
}

/// The title page's toast: the app's one toast card (`GlassToastView`).
struct DetailToastView: View {
    let toast: DetailToast
    let dismiss: () -> Void

    var body: some View {
        GlassToastView(symbol: toast.symbol, tint: toast.color, title: toast.title, message: toast.message,
                       actionLabel: toast.actionLabel, action: toast.action, dismiss: dismiss)
    }
}
