import SwiftUI
import FusionhaKit

/// The decline reason picker (web `DeclineReasonSheet`): Cancel and the title
/// in the bar, "<title> · the requester sees this reason", the four reasons
/// with a check on the chosen one, and a solid danger button. `decline`
/// confirms a new decline; `change` re-picks the reason while the Undo
/// window is held.
struct DeclineReasonSheet: View {
    enum Mode { case decline, change }

    let title: String
    let mode: Mode
    let initial: RequestReason
    let onConfirm: (RequestReason) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason: RequestReason?

    private var current: RequestReason { reason ?? initial }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("\(title) · the requester sees this reason")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    ForEach(Array(RequestReason.allCases.enumerated()), id: \.element) { i, r in
                        if i > 0 { Divider().overlay(Theme.line) }
                        row(r)
                    }
                }
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Decline reason")
                Button {
                    onConfirm(current)
                    dismiss()
                } label: {
                    Text(mode == .change ? "Update reason" : "Decline request")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.onDanger)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.danger, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .background(Theme.panel)
            .navigationTitle(mode == .change ? "Change reason" : "Decline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
            }
        }
        .presentationDetents([.height(420), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .sensoryFeedback(.selection, trigger: reason)
    }

    private func row(_ r: RequestReason) -> some View {
        let on = r == current
        return Button { reason = r } label: {
            HStack {
                Text(r.title)
                    .font(.system(size: 15, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accentText : Theme.txt)
                Spacer()
                if on {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

/// The Inbox and Board's Undo host: the toast over the view, the reason sheet
/// for a decline with a reason, and "Change reason", which holds the 5 s
/// window while its sheet is open (ruling R5).
struct InboxUndoHost: ViewModifier {
    let inbox: InboxModel
    let viewerId: Int?
    @Binding var declining: MediaRequest?
    @State private var changing = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let decision = inbox.pending {
                    InboxUndoToast(decision: decision, onUndo: inbox.undo) {
                        inbox.pause()
                        changing = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
            }
            .animation(.snappy, value: inbox.pending)
            .sheet(item: $declining) { r in
                DeclineReasonSheet(title: inbox.title(r), mode: .decline, initial: .notAvailableYet) { reason in
                    inbox.decline(r, viewerId: viewerId, reason: reason)
                }
            }
            .sheet(isPresented: $changing, onDismiss: inbox.resume) {
                if let decision = inbox.pending {
                    DeclineReasonSheet(title: decision.title, mode: .change, initial: decision.reason) { inbox.setReason($0) }
                }
            }
    }
}

extension View {
    func inboxUndoHost(_ inbox: InboxModel, viewerId: Int?, declining: Binding<MediaRequest?>) -> some View {
        modifier(InboxUndoHost(inbox: inbox, viewerId: viewerId, declining: declining))
    }
}
