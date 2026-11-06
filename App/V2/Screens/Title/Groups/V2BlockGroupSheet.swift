import SwiftUI
import FusionhaKit

/// "Block <GROUP>?" from a release row (search, Files, History): the web's
/// block dialog in manual mode (0.4.239). Two choices, "Skip <GROUP> for
/// <Title>" (SUGGESTED, the default) or "Skip <GROUP> everywhere"; Cancel
/// and the chosen Skip. No custom-format option, no evidence.
struct V2BlockGroupSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: GroupBlockTarget
    let title: String
    /// Says it worked where the sheet was opened (the group, the toast's
    /// line); the title page's toast by default.
    var onBlocked: ((String, String) -> Void)?
    @State private var everywhere = false
    @State private var busy = false
    @State private var error: String?

    private var group: String { target.group }
    private var confirmTitle: String {
        HeldCopy.scopeLabel(everywhere ? .global : .item, group: group, title: title)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 0) {
                        choice(.item, suggested: true)
                        Divider().padding(.leading, 46)
                        choice(.global, suggested: false)
                    }
                    .background { ModuleSurface(radius: 20) }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.dangerText)
                    }
                    buttons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Block \(group)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func choice(_ scope: HeldCopy.BlockScope, suggested: Bool) -> some View {
        let on = (scope == .global) == everywhere
        return Button { everywhere = scope == .global } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(on ? Theme.accentText : Theme.mut)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(HeldCopy.scopeLabel(scope, group: group, title: title))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .multilineTextAlignment(.leading)
                        if suggested { V2ReleaseCard.filledTag(Text("SUGGESTED"), color: Theme.txt) }
                    }
                    Text(HeldCopy.consequences(scope, group: group, title: title).first ?? "")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button { Task { await block() } } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().controlSize(.small) } else { Image(systemName: "nosign") }
                    Text(confirmTitle).lineLimit(2)
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.primary)
            .disabled(busy || store.groupBlock(for: group) != nil)
            Button { dismiss() } label: {
                Text("Cancel").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.glass)
        }
    }

    private func block() async {
        busy = true
        error = await store.blockReleaseGroup(group, everywhere: everywhere, note: nil)
        busy = false
        guard error == nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let onBlocked { onBlocked(group, confirmTitle) } else {
            store.show(confirmTitle, title: "Release group blocked", variant: .success)
        }
        dismiss()
    }
}
