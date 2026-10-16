import SwiftUI
import FusionhaKit

/// "Not listed? Enter manually" (web `ManualUrlEntry`): the URL field, Save URL
/// and the remove-URL warnings. A typed address is tested by Test connection.
struct PlexManualURLEntry: View {
    let saved: String
    let saving: Bool
    let backLabel: String?
    let lost: Int
    let libraries: [PlexLibrary]
    let onSave: (String) -> Void
    let onBack: () -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var dirty: Bool { trimmed != saved }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label: "Enter an address",
                       description: "Any URL fusionha can reach, with the port. It's tested when you press Test connection.")
            TextField("", text: $draft, prompt: Text("https://plex.example.com:32400").foregroundStyle(Theme.dim))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focused ? Theme.indigo : Theme.line, lineWidth: focused ? 2 : 1))
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(save)
                .accessibilityLabel("Plex server URL")
            HStack(spacing: 8) {
                Button("Save URL", action: save)
                    .buttonStyle(.web())
                    .disabled(saving || !dirty)
                if let backLabel {
                    Button(backLabel, action: onBack).buttonStyle(.web(.ghost))
                }
                Spacer(minLength: 0)
            }
            if !saved.isEmpty && trimmed.isEmpty {
                PlexURLClearWarning(lost: lost, libraries: libraries)
            }
        }
        .padding(.vertical, 4)
        .onAppear { draft = saved }
    }

    private func save() {
        if dirty && !saving { onSave(trimmed) }
    }
}

/// Shown while the field is emptied over a saved URL, BEFORE saving (web
/// `UrlClearWarning`): which libraries count as 4K only through path
/// detection and would drop to a name-only guess.
struct PlexURLClearWarning: View {
    let lost: Int
    let libraries: [PlexLibrary]

    var body: some View {
        let titles = libraries.filter(\.lostWithoutServerUrl).map(\.title)
        let n = max(lost, titles.count)
        if n == 0 {
            PlexNote(color: Theme.dim, symbol: "info.circle",
                     text: "Saving an empty URL disconnects the server. Library names are still read from your Plex account.")
        } else {
            PlexNote(color: Theme.stuck, symbol: "exclamationmark.triangle",
                     title: "Removing the server URL will drop \(n) \(n == 1 ? "library's" : "libraries'") 4K status",
                     text: detail(titles))
        }
    }

    private func detail(_ titles: [String]) -> String {
        let lead = titles.isEmpty ? ""
            : "\(titles.joined(separator: ", ")) count\(titles.count == 1 ? "s" : "") as 4K only through path detection. "
        return lead + "Without a URL, fusionha can only guess from library names, and a guess never applies until you confirm it. Fewer people may be able to request UHD·4K."
    }
}
