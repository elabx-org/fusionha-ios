import SwiftUI
import FusionhaKit

/// The web's desktop request thread (`RequestThread`, `data-layout='panel'`):
/// a right-hand panel over the Requests view, 460 wide (or the trailing half
/// past a fold), with a dimmed backdrop that closes it. Opened from Inbox,
/// Board and History when the Requests pane is wide (DU5); the phone keeps
/// the sheet.
struct RequestThreadOverlay: View {
    @Binding var thread: MediaRequest?
    let onChanged: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                if let request = thread {
                    Theme.scrim.opacity(0.32)
                        .contentShape(Rectangle())
                        .onTapGesture { thread = nil }
                        .accessibilityLabel("Close conversation")
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity)
                    RequestThreadPane(request: request, onClose: { thread = nil }, onChanged: onChanged)
                        .frame(width: TrailingPanelWidth.width(proxy))
                        .id(request.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: thread?.id)
    }
}

/// The panel itself: "Conversation" with Close, then the thread.
struct RequestThreadPane: View {
    let request: MediaRequest
    let onClose: () -> Void
    let onChanged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversation").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            Rectangle().fill(Theme.line).frame(height: 1)
            RequestThreadView(request: request, onChanged: onChanged)
        }
        .background(Theme.bg)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
    }
}
