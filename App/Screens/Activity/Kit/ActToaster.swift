import SwiftUI
import FusionhaKit

// MARK: Toasts

@MainActor
@Observable
final class ActToaster {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var tone: Tone = .info
        var undoLabel: String?
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    enum Tone { case info, success, warning, error }

    private(set) var current: Toast?
    private var undo: (() -> Void)?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, tone: Tone = .info, undoLabel: String? = nil, undo: (() -> Void)? = nil) {
        current = Toast(text: text, tone: tone, undoLabel: undo == nil ? nil : (undoLabel ?? "Undo"))
        self.undo = undo
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(undo == nil ? 3.5 : 6))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func error(_ error: Error, fallback: String? = nil) {
        if let api = error as? APIError, let message = api.serverDetail {
            show(message, tone: .error)
        } else {
            show(fallback ?? error.localizedDescription, tone: .error)
        }
    }

    func runUndo() {
        let action = undo
        undo = nil
        current = nil
        action?()
    }

    func dismiss() { current = nil }
}

struct ActToastOverlay: View {
    let toaster: ActToaster
    @Environment(\.actReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            if let toast = toaster.current {
                HStack(spacing: 10) {
                    Circle().fill(color(toast.tone)).frame(width: 7, height: 7)
                    Text(toast.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let undo = toast.undoLabel {
                        Button(undo) { toaster.runUndo() }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.cyan)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .onTapGesture { toaster.dismiss() }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: toaster.current)
        .allowsHitTesting(toaster.current != nil)
    }

    private func color(_ tone: ActToaster.Tone) -> Color {
        switch tone {
        case .info: return Theme.cyan
        case .success: return Theme.done
        case .warning: return Theme.miss
        case .error: return Theme.danger
        }
    }
}

// MARK: Confirm dialog (mobile Dialog as a bottom sheet)

struct ActDialog<Options: View>: View {
    let title: String
    let message: String
    let confirmLabel: String
    var confirmKind: ActButtonKind = .danger
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ViewBuilder var options: Options

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            Text(message)
                .font(.system(size: 13))
                .lineSpacing(13 * 0.5 / 2)
                .foregroundStyle(Theme.mut)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) { options }
                .padding(.top, 16)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel).buttonStyle(ActButtonStyle(kind: .subtle, small: false))
                Button(action: onConfirm) {
                    HStack(spacing: 6) {
                        if busy { ProgressView().controlSize(.mini) }
                        Text(confirmLabel).lineLimit(2).multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(ActButtonStyle(kind: confirmKind, small: false))
                .disabled(busy)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }
}

/// A dialog option row: native toggle + optional hint.
struct ActOption: View {
    let label: String
    var hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13)).foregroundStyle(Theme.txt)
                if let hint { Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            }
        }
        .tint(Theme.indigo)
    }
}
