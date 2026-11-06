import SwiftUI
import FusionhaKit

/// "Block a group" on one W1 card: the group (typed, with the groups seen
/// on this title as suggestions, or fixed when a row opened it), the
/// "Everywhere" switch (off: this title only), an optional note, what the
/// block does, and the primary "Block <GROUP>". A manual block
/// (`reason: manual`, `source: api`) through `DetailStore.blockReleaseGroup`.
struct V2BlockGroupForm: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let title: String
    /// The row's group; nil shows the field and its suggestions.
    var fixedGroup: String?
    /// After a block: the group and whether it was everywhere.
    let onBlocked: (String, Bool) -> Void
    @State private var typed = ""
    @State private var everywhere = false
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    private var group: String? { TitleGroupBlocks.display(fixedGroup ?? typed) }
    private var existing: ReleaseGroupBlock? { store.groupBlock(for: group) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if fixedGroup == nil {
                Text("Block a group")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                field
                V2GroupSuggestions(typed: typed) { typed = $0; fieldFocused = false }
            }
            Toggle(isOn: $everywhere) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Everywhere").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(everywhere ? "Every movie, series and anime" : "Off: only \(title)")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
            .tint(Theme.primary)
            TextField("Note (optional)", text: $note, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            consequences
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dangerText)
            }
            blockButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 20) }
        .animation(reduce ? nil : .easeOut(duration: 0.2), value: everywhere)
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

    @ViewBuilder
    private var consequences: some View {
        if let group {
            if let existing {
                Label("\(group) is already blocked: \(TitleGroupBlocks.scopeLabel(existing)).", systemImage: "nosign")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines(group), id: \.self) { Text($0) }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func lines(_ group: String) -> [String] {
        let first = HeldCopy.consequences(everywhere ? .global : .item, group: group, title: title).first ?? ""
        return [first, "Files already on disk stay. Unblock it here at any time."]
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
        error = await store.blockReleaseGroup(group, everywhere: everywhere, note: note)
        busy = false
        guard error == nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let wasEverywhere = everywhere
        typed = ""
        note = ""
        everywhere = false
        onBlocked(group, wasEverywhere)
    }
}
