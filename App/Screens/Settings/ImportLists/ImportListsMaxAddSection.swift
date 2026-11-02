import SwiftUI
import FusionhaKit

/// The global "Add at most per sync" cap (`import_list_max_add_per_sync`,
/// 1–200, default 25), under the lists (web `MaxAddRow`). Saves on its own.
struct ImportListsMaxAddSection: View {
    @Environment(SettingsStore.self) private var settings
    private static let key = "import_list_max_add_per_sync"

    var body: some View {
        let value = settings.int(Self.key, 25)
        Section {
            Picker(ImportListCopy.maxAdd, selection: Binding(get: { value }, set: { settings.save(Self.key, .number(Double($0))) })) {
                ForEach(options(value), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .settingsField(ImportListCopy.maxAdd)
        } header: {
            Text(ImportListCopy.maxAdd)
        } footer: {
            Text(ImportListCopy.maxAddDesc)
        }
    }

    /// The presets, plus the saved value when it is none of them.
    private func options(_ value: Int) -> [Int] {
        ImportListCopy.maxAddPresets.contains(value) ? ImportListCopy.maxAddPresets : (ImportListCopy.maxAddPresets + [value]).sorted()
    }
}
