import SwiftUI
import FusionhaKit

/// "Folder": the folder name (renames inline — sent only when it differs from
/// the default) and one Plex-ready path per enabled version, the
/// `{edition-…}` token in the variant colour. A 409 collision washes the row
/// amber and reopens the field.
struct AddFolderRow: View {
    let flow: AddFlow
    @State private var editing = false
    @State private var before = ""
    @FocusState private var focused: Bool
    @Environment(\.addLook) private var look
    @Environment(\.pagePalette) private var page

    private var conflict: String? { flow.error?.folder == true ? flow.error?.message : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Folder").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                if !flow.onTiers.isEmpty {
                    if editing {
                        TextField("", text: Binding(get: { flow.folderName }, set: { flow.setFolderName($0) }),
                                  prompt: Text(flow.derivedFolder).foregroundStyle(Theme.dim))
                            .font(.system(size: 13.5, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focused)
                            .onSubmit { editing = false }
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(conflict != nil ? Theme.miss.opacity(0.6) : Theme.line))
                        iconButton("checkmark", label: "Done renaming") { editing = false }
                    } else {
                        Spacer(minLength: 8)
                        Text(flow.shownFolder)
                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        iconButton("pencil", label: "Rename folder") {
                            before = flow.folderName
                            editing = true
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            if flow.onTiers.isEmpty {
                if flow.ready {
                    Text("Turn on a version to see where it goes.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .padding(.horizontal, 14).padding(.bottom, 12)
                } else {
                    SkeletonBar(height: 14, radius: 5).padding(.horizontal, 14).padding(.bottom, 12)
                }
            }
            ForEach(flow.onTiers, id: \.self) { tier in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(tier.pill)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AddInks(look: look, page: page).tier(tier))
                    path(tier)
                        .font(.system(size: 12, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            if let conflict {
                Text(conflict)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(conflict != nil ? Theme.miss.opacity(0.1) : .clear)
        .onChange(of: conflict) { if conflict != nil { editing = true } }
        .onChange(of: editing) { focused = editing }
    }

    private func path(_ tier: QualityTier) -> Text {
        let root = flow.roots?.first { $0.id == flow.versions?[tier]?.rootId }?.path ?? ""
        var trimmed = root
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let edition = flow.editions[tier]
        var text = Text(trimmed + "/").foregroundColor(Theme.dim) + Text(flow.shownFolder).foregroundColor(Theme.txt)
        if !AddVocab.isStandardEdition(edition), let edition {
            text = text + Text(" {edition-\(edition)}").foregroundColor(Theme.anime)
        }
        return text
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
