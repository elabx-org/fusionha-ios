import SwiftUI
import FusionhaKit

/// Edit item's Tags section: the chosen tags as removable chips, a field that
/// adds (or creates) a tag, and a menu of the server's other tags.
struct EditTagsSection: View {
    @Environment(DetailStore.self) private var store
    @Binding var selectedTags: [ItemTag]
    @Binding var allTags: [ItemTag]
    @Binding var tagInput: String

    var body: some View {
        Section("Tags") {
            if selectedTags.isEmpty {
                Text("No tags").foregroundStyle(Theme.mut)
            } else {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(selectedTags) { tag in
                        Button {
                            withAnimation(DetailMotion.quick) { selectedTags.removeAll { $0.id == tag.id } }
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
                let available = allTags.filter { t in !selectedTags.contains { $0.id == t.id } }
                if !available.isEmpty {
                    Menu {
                        ForEach(available) { tag in
                            Button(tag.label) { selectedTags.append(tag) }
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
        if let existing = allTags.first(where: { $0.label.lowercased() == label.lowercased() }) {
            if !selectedTags.contains(where: { $0.id == existing.id }) { selectedTags.append(existing) }
            return
        }
        guard let client = store.client else { return }
        do {
            let tag = try await client.createTag(label: label)
            allTags.append(tag)
            selectedTags.append(tag)
        } catch {
            store.show("Couldn't create the tag \(label)", variant: .error)
        }
    }
}
