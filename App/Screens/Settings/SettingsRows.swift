import SwiftUI
import FusionhaKit

// MARK: Sections and rows

/// A Form section: a sentence-case title (15/600 `--mut`) and the card colour
/// behind its rows.
struct SettingsSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .textCase(nil)
                    .foregroundStyle(Theme.mut)
            }
        } footer: {
            if let footer {
                Text(footer).font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.line)
    }
}

/// The web's label (13.5/600 `--txt`) + description (12 `--mut`) stack.
struct FieldLabel: View {
    let label: String
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
            if let description {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A Switch row that autosaves one boolean setting.
struct SettingToggle: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    var fallback = false

    var body: some View {
        Toggle(isOn: store.boolBinding(key, fallback)) {
            FieldLabel(label: label, description: description)
        }
        .tint(Theme.indigo)
        .settingsField(label)
    }
}

/// A menu Picker row that autosaves one setting.
struct SettingPicker<Value: Hashable>: View {
    let label: String
    var description: String?
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options.indices, id: \.self) { i in
                Text(options[i].1).tag(options[i].0)
            }
        } label: {
            FieldLabel(label: label, description: description)
        }
        .pickerStyle(.menu)
        .tint(Theme.mut)
        .settingsField(label)
    }
}

/// The web's `NumberField`: a bounded number with a trailing unit, committed
/// on Return or when the field loses focus, only if it changed.
struct SettingNumber: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    let unit: String
    var signed = false
    var min: Double?
    var max: Double?
    var integer = true
    var disabled = false

    var body: some View {
        NumberFieldRow(label: label, description: description, unit: unit,
                       value: store.double(key), signed: signed, min: min, max: max, integer: integer) { n in
            store.save(key, .number(n))
        }
        .disabled(disabled)
    }
}

struct NumberFieldRow: View {
    let label: String
    var description: String?
    let unit: String
    let value: Double
    var signed = false
    var min: Double?
    var max: Double?
    var integer = true
    let onSave: (Double) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        LabeledContent {
            HStack(spacing: 7) {
                TextField("", text: $text)
                    .keyboardType(signed ? .numbersAndPunctuation : (integer ? .numberPad : .decimalPad))
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(enabled ? Theme.txt : Theme.dim)
                    .padding(.horizontal, 9)
                    .frame(width: 72, height: 34)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(focused ? Theme.indigo : Theme.line, lineWidth: focused ? 2 : 1))
                    .focused($focused)
                    .onSubmit(commit)
                    .accessibilityLabel(label)
                Text(unit).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        } label: {
            FieldLabel(label: label, description: description)
        }
        .onAppear { text = format(value) }
        .onChange(of: value) { text = format(value) }
        .onChange(of: focused) { if !focused { commit() } }
        .settingsField(label)
    }

    private func format(_ n: Double) -> String {
        integer || n.rounded() == n ? String(Int(n)) : String(n)
    }

    private func commit() {
        guard let raw = Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")),
              raw.isFinite else {
            text = format(value)
            return
        }
        var n = integer ? raw.rounded() : (raw * 100).rounded() / 100
        if !signed { n = Swift.max(min ?? 0, n) } else if let min { n = Swift.max(min, n) }
        if let max { n = Swift.min(max, n) }
        if n != value { onSave(n) }
        text = format(n)
    }
}

/// A text field row that autosaves on Return or blur, only if it changed.
struct SettingText: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    var placeholder = ""
    var trims = true
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label: label, description: description)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.dim))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focused ? Theme.indigo : Theme.line, lineWidth: focused ? 2 : 1))
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .accessibilityLabel(label)
        }
        .padding(.bottom, 4)
        .onAppear { text = store.string(key) }
        .onChange(of: store.string(key)) { if !focused { text = store.string(key) } }
        .onChange(of: focused) { if !focused { commit() } }
        .settingsField(label)
    }

    private func commit() {
        let next = trims ? text.trimmingCharacters(in: .whitespaces) : text
        if next != store.string(key) { store.save(key, .string(next)) }
        text = next
    }
}

/// A read-only label ↔ value row.
struct SettingValueRow<Value: View>: View {
    let label: String
    var description: String?
    @ViewBuilder var value: Value

    var body: some View {
        LabeledContent {
            value
        } label: {
            FieldLabel(label: label, description: description)
        }
        .settingsField(label)
    }
}

/// Monospaced muted text (the web's `.mono`).
struct MonoText: View {
    let text: String
    var color: Color = Theme.mut

    init(_ text: String, color: Color = Theme.mut) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(color)
    }
}
