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
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

struct DetailToastView: View {
    let toast: DetailToast
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toast.symbol).foregroundStyle(toast.color).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13)).foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
            }
            Spacer(minLength: 0)
            if let label = toast.actionLabel, let action = toast.action {
                Button(label) { action(); dismiss() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.i2)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .onTapGesture(perform: dismiss)
    }
}
