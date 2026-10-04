import SwiftUI
import FusionhaKit

// Shared building blocks for the native Settings panels: the autosaving
// settings store, the motion rules, the web's card + field-row look on a
// native Form, and the search flash.

// MARK: Store

/// `GET /api/v1/settings`, held once for the whole Settings stack. Every control
/// saves just the key it owns (`PUT /api/v1/settings {key: value}`), optimistically,
/// and rolls back if the server refuses — the web's autosave model.
@MainActor
@Observable
final class SettingsStore {
    private(set) var values: [String: JSONValue] = [:]
    private(set) var loaded = false
    var error: String?
    /// The last failed save, shown as a banner until dismissed.
    var saveError: String?
    let client: APIClient?
    /// The singleton document this store edits: `/api/v1/settings` or, for
    /// File Management, `/api/v1/media-management` (same GET + partial PUT shape).
    let path: String

    init(client: APIClient?, path: String = "/api/v1/settings") {
        self.client = client
        self.path = path
    }

    func load() async {
        guard let client else { return }
        do {
            values = try await client.json("GET", path).object ?? [:]
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    subscript(key: String) -> JSONValue? { values[key] }

    func bool(_ key: String, _ fallback: Bool = false) -> Bool { values[key]?.bool ?? fallback }
    func int(_ key: String, _ fallback: Int = 0) -> Int { values[key]?.int ?? fallback }
    func double(_ key: String, _ fallback: Double = 0) -> Double { values[key]?.double ?? fallback }
    func string(_ key: String, _ fallback: String = "") -> String { values[key]?.string ?? fallback }

    func save(_ key: String, _ value: JSONValue) {
        save([key: value])
    }

    func save(_ diff: [String: JSONValue]) {
        let before = diff.keys.reduce(into: [String: JSONValue]()) { $0[$1] = values[$1] ?? .null }
        for (k, v) in diff { values[k] = v }
        guard let client else { return }
        Task {
            do {
                let fresh = try await client.json("PUT", path, body: .object(diff)).object ?? [:]
                if !fresh.isEmpty { values.merge(fresh) { _, new in new } }
            } catch {
                for (k, v) in before { values[k] = v }
                saveError = "Couldn’t save — \(error.localizedDescription)"
            }
        }
    }

    func boolBinding(_ key: String, _ fallback: Bool = false) -> Binding<Bool> {
        Binding(get: { self.bool(key, fallback) }, set: { self.save(key, .bool($0)) })
    }

    func intBinding(_ key: String, _ fallback: Int = 0) -> Binding<Int> {
        Binding(get: { self.int(key, fallback) }, set: { self.save(key, .number(Double($0))) })
    }

    func stringBinding(_ key: String, _ fallback: String = "") -> Binding<String> {
        Binding(get: { self.string(key, fallback) }, set: { self.save(key, .string($0)) })
    }

    /// The web's `animations_enabled` (General → Enable animations).
    var animationsEnabled: Bool { bool("animations_enabled", true) }
}

// MARK: Motion

/// True when Settings should not animate: the system Reduce Motion setting or
/// the app's own "Enable animations" switch (the web honours both).
private struct SettingsMotionOffKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var settingsMotionOff: Bool {
        get { self[SettingsMotionOffKey.self] }
        set { self[SettingsMotionOffKey.self] = newValue }
    }
}

/// Pushes a panel by slug onto the Settings stack (honours motion-off).
private struct SettingsPushKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var settingsPush: (String) -> Void {
        get { self[SettingsPushKey.self] }
        set { self[SettingsPushKey.self] = newValue }
    }
}

enum SettingsMotion {
    /// The prototype's smooth, non-elastic ease (`REVEAL_EASE`).
    static func reveal(_ duration: Double = 0.5) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }

    /// The chevron / colour transition (`transition: transform 0.2s ease`).
    static let chevron = Animation.easeInOut(duration: 0.2)

    /// Runs a state change animated, or instantly when motion is off.
    static func perform(_ off: Bool, _ animation: Animation = chevron, _ change: () -> Void) {
        if off {
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t, change)
        } else {
            withAnimation(animation, change)
        }
    }
}

/// The web's `<Reveal>`: content rises 16pt and fades in over 0.5s.
private struct SettingsReveal: ViewModifier {
    @Environment(\.settingsMotionOff) private var motionOff
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(motionOff || shown ? 1 : 0)
            .offset(y: motionOff || shown ? 0 : 16)
            .onAppear {
                guard !motionOff, !shown else { return }
                withAnimation(SettingsMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

extension View {
    func settingsReveal(delay: Double = 0) -> some View {
        modifier(SettingsReveal(delay: delay))
    }
}

// MARK: Search flash

/// The field a Settings search jumped to; the matching row flashes cyan for
/// ~2.2s (the web's `.searchFlash`), then the target clears after 2.4s.
@MainActor
@Observable
final class SettingsFlash {
    private(set) var panel: String?
    private(set) var label: String?
    private var generation = 0

    func set(panel: String, label: String?) {
        self.panel = panel
        self.label = label
        generation += 1
        let mine = generation
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if generation == mine { self.label = nil; self.panel = nil }
        }
    }

    func target(in panel: String) -> String? {
        self.panel == panel ? label : nil
    }
}

private struct FlashRowBackground: View {
    let active: Bool
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var lit = false

    var body: some View {
        Theme.card
            .overlay(Theme.cyan.opacity(lit ? 0.12 : 0))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.cyan.opacity(lit ? 0.7 : 0), lineWidth: 2))
            .onAppear { if active { flash() } }
            .onChange(of: active) { if active { flash() } }
    }

    private func flash() {
        lit = true
        // Hold for 55% of 2.2s, then fade out (instant under reduced motion).
        Task {
            try? await Task.sleep(for: .seconds(motionOff ? 0.6 : 1.2))
            if motionOff { lit = false } else { withAnimation(.easeOut(duration: 1.0)) { lit = false } }
        }
    }
}

private struct SettingsFieldModifier: ViewModifier {
    let label: String
    @Environment(SettingsFlash.self) private var flash
    @Environment(\.settingsPanelSlug) private var slug

    func body(content: Content) -> some View {
        content
            .id(label)
            .listRowBackground(FlashRowBackground(active: flash.target(in: slug) == label))
    }
}

private struct SettingsPanelSlugKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var settingsPanelSlug: String {
        get { self[SettingsPanelSlugKey.self] }
        set { self[SettingsPanelSlugKey.self] = newValue }
    }
}

extension View {
    /// Marks a Form row as the setting `label`, so a search hit can scroll to it
    /// and flash it. Also paints the web's card colour behind the row.
    func settingsField(_ label: String) -> some View {
        modifier(SettingsFieldModifier(label: label))
    }
}

// MARK: Page

/// A native panel page: a dark Form whose first block is the web's panel
/// heading (20/750) and subtitle (13 `--mut`), revealed on entry. Scrolls to
/// and flashes a searched-for field.
struct SettingsForm<Content: View>: View {
    let slug: String
    @ViewBuilder var content: Content
    @Environment(SettingsFlash.self) private var flash

    private var info: SettingsPanelInfo? { SettingsNav.panel(slug) }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info?.title ?? slug)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Theme.txt)
                        Text(info?.subtitle ?? "")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .textCase(nil)
                    .padding(.horizontal, -4)
                    .settingsReveal()
                }
                content
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .environment(\.settingsPanelSlug, slug)
            .task(id: flash.target(in: slug)) {
                guard let label = flash.target(in: slug) else { return }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.smooth) { proxy.scrollTo(label, anchor: .center) }
            }
        }
        .navigationTitle(info?.title ?? slug)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { SettingsSaveErrorBanner() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private struct SettingsSaveErrorBanner: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        if let message = store.saveError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger)
                Text(message).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                Button { store.saveError = nil } label: { Image(systemName: "xmark") }
                    .foregroundStyle(Theme.mut)
                    .accessibilityLabel("Dismiss")
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .task(id: message) {
                try? await Task.sleep(for: .seconds(5))
                if store.saveError == message { store.saveError = nil }
            }
        }
    }
}

// MARK: Sections and rows

/// A Form section with the web's section title (12.5/700 uppercase `--mut`)
/// and the card colour behind its rows.
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
                    .font(.system(size: 12.5, weight: .bold))
                    .tracking(0.25)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.mut)
            }
        } footer: {
            if let footer {
                Text(footer).font(.system(size: 12)).foregroundStyle(Theme.mut)
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

// MARK: Buttons

/// The web's `Button` (size sm): 30 tall, 12/650, radius 9.
struct WebButtonStyle: ButtonStyle {
    enum Variant { case subtle, ghost, danger, primary }
    var variant: Variant = .subtle
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: variant == .primary ? .bold : .semibold))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border))
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(enabled ? 1 : 0.5)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch variant {
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .primary: return Theme.bg
        }
    }

    private var background: AnyShapeStyle {
        switch variant {
        case .subtle: return AnyShapeStyle(Theme.panel)
        case .ghost, .danger: return AnyShapeStyle(Color.clear)
        case .primary: return AnyShapeStyle(Theme.fusion)
        }
    }

    private var border: Color {
        switch variant {
        case .subtle: return Theme.line
        case .ghost, .primary: return .clear
        case .danger: return Theme.danger.opacity(0.4)
        }
    }
}

extension ButtonStyle where Self == WebButtonStyle {
    static func web(_ variant: WebButtonStyle.Variant = .subtle) -> WebButtonStyle { WebButtonStyle(variant: variant) }
}

/// Loading / error placeholder for a panel body.
struct SettingsLoadingRow: View {
    var error: String?

    var body: some View {
        HStack(spacing: 10) {
            if let error {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.miss)
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                ProgressView().controlSize(.small)
                Text("Loading…").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .listRowBackground(Theme.card)
    }
}
