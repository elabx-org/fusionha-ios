import SwiftUI
import FusionhaKit

/// A masked key with a pencil; editing shows a secure field with Save / Cancel.
struct ApiKeyCell: View {
    let key: String
    let configuredKey: String
    let label: String
    let sub: String
    @Environment(SettingsStore.self) private var store
    @State private var editing = false
    @State private var value = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FieldLabel(label: label, description: sub)
                Spacer()
                if !editing {
                    MonoText(store.bool(configuredKey) ? "•••• •••• ••••" : "Not set")
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(.web())
                        .accessibilityLabel("Change \(label)")
                }
            }
            if editing {
                SecureField("", text: $value, prompt: Text("Paste your \(label)").foregroundStyle(Theme.dim))
                    .font(.system(size: 13))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    .onSubmit(commit)
                HStack(spacing: 8) {
                    Button("Save", action: commit)
                        .buttonStyle(.web(.primary))
                        .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { editing = false; value = "" }
                        .buttonStyle(.web(.ghost))
                }
            }
        }
    }

    private func commit() {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.save(key, .string(trimmed))
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await store.load()
        }
        editing = false
        value = ""
    }
}

/// The web's `formatAgo`: "just now", "5 min ago", "3h ago", "2d ago", or a date.
func formatAgo(_ iso: String) -> String {
    guard let then = Format.timestamp(iso) else { return "" }
    let secs = max(0, Int(Date().timeIntervalSince(then)))
    if secs < 60 { return "just now" }
    let mins = secs / 60
    if mins < 60 { return "\(mins) min ago" }
    let hrs = mins / 60
    if hrs < 24 { return "\(hrs)h ago" }
    let days = hrs / 24
    if days < 7 { return "\(days)d ago" }
    return then.formatted(date: .numeric, time: .omitted)
}

/// TheTVDB's required attribution line, verbatim, with its mark and a link back.
struct TvdbAttribution: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            TvdbLogo(size: 20)
            Text("Metadata provided by TheTVDB. Please consider adding missing information or subscribing. [thetvdb.com ↗](https://thetvdb.com)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
                .tint(Theme.indigo)
        }
    }
}
