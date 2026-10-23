import SwiftUI
import FusionhaKit

/// "What was on it when you started" (web `StartMenu`): a menu picker showing
/// its value; a change saves the baseline (never cancels anything). The diary
/// reads "When you started", "Only new entries" / "Also request my recent entries".
struct BaselinePicker: View {
    let value: String
    let diary: Bool
    /// Titles noted and left alone at the start.
    var noted = 0
    var disabled = false
    /// Saves the choice; false puts the shown value back.
    let save: (String) async -> Bool
    @State private var shown: String?

    var body: some View {
        Picker(selection: Binding(get: { shown ?? value }, set: { pick($0) })) {
            Text(diary ? SourceDetailCopy.newOnlyDiary : SourceDetailCopy.newOnly).tag("new")
            Text(diary ? SourceDetailCopy.existingDiary : SourceDetailCopy.existing).tag("existing")
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(diary ? SourceDetailCopy.startedDiary : SourceDetailCopy.startedOn)
                if noted > 0 {
                    Text(SourceDetailCopy.noted(noted, diary: diary)).font(.caption).foregroundStyle(Theme.mut)
                }
            }
        }
        .pickerStyle(.menu)
        .disabled(disabled)
        .onChange(of: value) { shown = nil }
    }

    private func pick(_ next: String) {
        guard next != (shown ?? value) else { return }
        shown = next
        Task { if await !save(next) { shown = nil } }
    }
}
