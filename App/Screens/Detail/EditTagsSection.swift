import SwiftUI
import FusionhaKit

/// Edit › Tags: the chosen tags (tap to remove), a field that adds or creates
/// one, and a menu of the existing tags.
struct EditTagsSection: View {
    @Environment(DetailStore.self) private var store
    @Binding var selected: [ItemTag]
    @Binding var all: [ItemTag]
    @State private var tagInput = ""

    var body: some View {
        Section("Tags") {
            if selected.isEmpty {
                Text("No tags").foregroundStyle(Theme.mut)
            } else {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(selected) { tag in
                        Button {
                            withAnimation(DetailMotion.quick) { selected.removeAll { $0.id == tag.id } }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tag.label)
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.panel2, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove tag \(tag.label)")
                    }
                }
            }
            HStack {
                TextField("Add tag", text: $tagInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await addTag() } }
                let available = all.filter { t in !selected.contains { $0.id == t.id } }
                if !available.isEmpty {
                    Menu {
                        ForEach(available) { tag in
                            Button(tag.label) { selected.append(tag) }
                        }
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("Pick a tag")
                }
            }
        }
    }

    private func addTag() async {
        let label = tagInput.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        tagInput = ""
        if let existing = all.first(where: { $0.label.lowercased() == label.lowercased() }) {
            if !selected.contains(where: { $0.id == existing.id }) { selected.append(existing) }
            return
        }
        guard let client = store.client else { return }
        do {
            let tag = try await client.createTag(label: label)
            all.append(tag)
            selected.append(tag)
        } catch {
            store.show("Couldn't create the tag \(label)", variant: .error)
        }
    }
}
