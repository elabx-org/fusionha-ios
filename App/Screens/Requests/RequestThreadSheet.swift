import SwiftUI
import FusionhaKit

/// A request's thread as a sheet (the phone, and anywhere outside the
/// Requests area): `RequestThreadView` under a "Conversation" bar with Done.
/// Inside Requests, wide, the thread is the web's right-hand panel instead
/// (`RequestThreadPane`, DU5).
struct RequestThreadSheet: View {
    let request: MediaRequest
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RequestThreadView(request: request, onChanged: onChanged)
                .background(Theme.bg)
                .navigationTitle("Conversation")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        SheetDoneButton { dismiss() }
                    }
                }
                .closeOnlyBars()
        }
        .presentationDetents([.large])
        // Outside the Requests area (title detail, My requests) a form sheet unfolded.
        .formSheet()
    }
}

/// The message box: posts, then clears unless a newer draft was typed meanwhile.
struct RequestThreadComposer: View {
    let placeholder: String
    /// Posts one line (a request's or an issue's thread).
    let post: (APIClient, String) async throws -> RequestThreadEvent
    let onSent: (RequestThreadEvent) -> Void
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onChange(of: text) { if text.count > 2000 { text = String(text.prefix(2000)) } }
                .submitLabel(.send)
                .onSubmit { Task { await send() } }
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Theme.primary, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.horizontal, -4).padding(.vertical, -4)
            }
            .buttonStyle(.plain)
            .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send")
            .padding(.trailing, 5)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func send() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sending, !body.isEmpty, let client = model.client else { return }
        sending = true
        defer { sending = false }
        do {
            let line = try await post(client, body)
            if text.trimmingCharacters(in: .whitespacesAndNewlines) == body { text = "" }
            onSent(line)
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not send", variant: .error)
        }
    }
}
