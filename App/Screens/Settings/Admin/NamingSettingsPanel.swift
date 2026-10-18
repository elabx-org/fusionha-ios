import SwiftUI
import FusionhaKit

/// Settings › Naming (web `NamingPanel`): rename / illegal-character toggles,
/// the always-on series edition folder note, per-kind format fields, a token
/// palette that inserts into the focused field and the live colour-coded
/// full-path preview. Reads and autosaves `GET/PUT /api/v1/naming` one key at a time.
struct NamingSettingsPanel: View {
    @Environment(SettingsStore.self) private var settings
    @State private var store: SettingsStore?

    var body: some View {
        Group {
            if let store {
                NamingForm().environment(store)
            } else {
                Color.clear
            }
        }
        .task {
            guard store == nil else { return }
            let naming = SettingsStore(client: settings.client, path: "/api/v1/naming")
            store = naming
            await naming.load()
        }
    }
}

private struct NamingForm: View {
    @Environment(SettingsStore.self) private var store
    @State private var kind: NamingKind = .series
    @State private var drafts: [String: String] = [:]
    /// The field a token chip inserts into (the last one focused in this kind).
    @State private var target = "series_folder_format"
    @FocusState private var focused: String?

    var body: some View {
        SettingsForm(slug: "naming") {
            if !store.loaded {
                SettingsLoadingRow()
            } else if let error = store.error, store.values.isEmpty {
                SettingsLoadingRow(error: error)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        SettingsSection {
            SettingToggle(key: "rename_enabled", label: "Rename files")
            SettingToggle(key: "replace_illegal_characters", label: "Replace illegal characters", fallback: true)
        }
        SettingsSection {
            NamingSeriesEditionNote().settingsField("Series edition folders")
        }
        SettingsSection {
            Picker("Media kind", selection: $kind) {
                ForEach(NamingKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { target = NamingFormat.fields(kind)[0].key }
            ForEach(NamingFormat.fields(kind)) { field in
                NamingFormatField(field: field, text: binding(field.key), focused: $focused) { commit(field.key) }
            }
        }
        SettingsSection("Insert token — into the focused field") {
            NamingTokenPalette(tokens: NamingFormat.tokens(kind)) { insert($0) }
                .settingsField("Insert token")
        }
        SettingsSection {
            NamingPreview(kind: kind, value: value, replaceIllegal: store.bool("replace_illegal_characters", true))
        }
        .onChange(of: focused) { old, new in
            if let old, old != new { commit(old) }
            if let new { target = new }
        }
    }

    private func value(_ key: String) -> String { drafts[key] ?? store.string(key) }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { value(key) }, set: { drafts[key] = $0 })
    }

    /// Saves a field's draft if it changed; an empty anime format is `null`.
    private func commit(_ key: String) {
        guard let draft = drafts[key] else { return }
        drafts[key] = nil
        guard draft != store.string(key) else { return }
        if key == NamingFormat.animeKey && draft.trimmingCharacters(in: .whitespaces).isEmpty {
            store.save(key, .null)
        } else {
            store.save(key, .string(draft))
        }
    }

    /// Appends the token to the target field; saves straight away unless the
    /// field is still being edited (then it saves when editing ends).
    private func insert(_ token: String) {
        let key = focused ?? target
        drafts[key] = value(key) + token
        if focused != key { commit(key) }
    }
}

/// One format field: its label, the config key in mono, and the text box.
private struct NamingFormatField: View {
    let field: NamingField
    @Binding var text: String
    var focused: FocusState<String?>.Binding
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(field.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                MonoText(field.key, color: Theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            TextField("", text: $text, prompt: Text(field.placeholder ?? "").foregroundStyle(Theme.dim))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 11)
                .frame(minHeight: 36)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focused.wrappedValue == field.key ? Theme.indigo : Theme.line,
                                  lineWidth: focused.wrappedValue == field.key ? 2 : 1))
                .focused(focused, equals: field.key)
                .submitLabel(.done)
                .onSubmit { focused.wrappedValue = nil; onCommit() }
                .accessibilityLabel(field.label)
        }
        .padding(.vertical, 4)
        .settingsField(field.label)
    }
}

/// The read-only series edition copy (Plex parity: always on, no toggle).
private struct NamingSeriesEditionNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Series editions always get their own **show folder**: `Show (Year) {edition-Black & White}/`, the folder Plex reads (**Plex Pass**; Jellyfin too).")
            Text("The token never goes in season folders or episode filenames; the Standard edition keeps its plain folder. Each edition tracks watch state **independently**; on clients without edition support they show as separate items, so give each its own **poster**. Existing editions in an older layout move only when you run **Rename files** on the title.")
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.mut)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }
}

/// The token chips (web `.tokens`); `{Custom Formats}` takes the edition tint.
private struct NamingTokenPalette: View {
    let tokens: [String]
    let onInsert: (String) -> Void

    var body: some View {
        FetchFlow(spacing: 6, lineSpacing: 6) {
            ForEach(tokens, id: \.self) { token in
                let tint = token.contains("Custom Formats") ? Theme.edition : Theme.i2
                Button { onInsert(token) } label: {
                    Text(token)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(tint.opacity(0.28)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert \(token)")
            }
        }
        .padding(.vertical, 6)
    }
}
