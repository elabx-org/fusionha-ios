import SwiftUI
import FusionhaKit

/// "Block a group" in the Release groups sheet (web 0.4.239), on one W1
/// card: the name field with one-tap suggestions ("Seen on this title"),
/// the "Everywhere" switch (off: this title only), "Block <GROUP>", and a
/// link to Activity › Blocklist. A manual block (`reason: manual`,
/// `source: api`) through `DetailStore.blockReleaseGroup`.
struct V2BlockGroupForm: View {
    @Environment(DetailStore.self) private var store
    let title: String
    let openBlocklist: () -> Void
    @State private var typed = ""
    @State private var everywhere = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    private var group: String? { TitleGroupBlocks.display(typed) }
    private var existing: ReleaseGroupBlock? { store.groupBlock(for: group) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Block a group")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            field
            V2GroupSuggestions(typed: typed) { typed = $0; fieldFocused = false }
            Toggle(isOn: $everywhere) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everywhere").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(everywhere ? "Every movie, series and anime" : "Off: only \(title)")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
            .tint(Theme.primary)
            if let group, let existing {
                Label("\(group) is already blocked: \(TitleGroupBlocks.scopeLabel(existing)).", systemImage: "nosign")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dangerText)
            }
            blockButton
            Button(action: openBlocklist) {
                Label("Blocklist", systemImage: "arrow.up.right")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Opens Activity, Blocklist")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 20) }
    }

    private var field: some View {
        TextField("Group name, e.g. YIFY", text: $typed)
            .font(.system(size: 16, weight: .semibold))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($fieldFocused)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Group name")
    }

    private var blockButton: some View {
        Button {
            Task { await block() }
        } label: {
            HStack(spacing: 6) {
                if busy { ProgressView().controlSize(.small) } else { Image(systemName: "nosign") }
                Text(group.map { "Block \($0)" } ?? "Block a group")
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.primary)
        .disabled(group == nil || existing != nil || busy)
    }

    private func block() async {
        guard let group else { return }
        busy = true
        error = await store.blockReleaseGroup(group, everywhere: everywhere, note: nil)
        busy = false
        guard error == nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        typed = ""
        everywhere = false
    }
}
