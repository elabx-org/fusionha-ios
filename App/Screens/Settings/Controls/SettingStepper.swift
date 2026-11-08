import SwiftUI
import FusionhaKit

/// A small count in Settings (owner-approved number controls, 2026-11-08):
/// the value and a native stepper. Taps change it at once and save once they
/// stop, so a run of taps is one request.
struct SettingStepper: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    var min = 0
    var max = 1000
    var step = 1
    var fallback = 0
    var disabled = false
    /// Words for the value; when set, they sit under the title instead of
    /// beside the stepper ("5 days before").
    var words: ((Int) -> String)?
    @State private var value: Int?

    private var current: Int { value ?? store.int(key, fallback) }

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                if words == nil {
                    Text("\(current)")
                        .font(.system(size: 15).monospacedDigit())
                        .foregroundStyle(disabled ? Theme.dim : Theme.mut)
                        .contentTransition(.numericText(value: Double(current)))
                }
                Stepper(label, value: Binding(get: { current }, set: { value = $0 }),
                        in: min...max, step: step)
                    .labelsHidden()
                    .accessibilityLabel(label)
                    .accessibilityValue(words?(current) ?? "\(current)")
            }
        } label: {
            FieldLabel(label: label, description: description, value: words?(current))
        }
        .disabled(disabled)
        .settingsField(label)
        .task(id: value) {
            guard let value else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            if value != store.int(key, fallback) { store.save(key, .number(Double(value))) }
            self.value = nil
        }
    }
}

/// A fraction 0–1 shown as a percentage, saved once the slider settles.
struct SettingPercent: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    var fallback = 0.0
    var step = 0.05
    @State private var value: Double?

    private var current: Double { value ?? store.double(key, fallback) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                FieldLabel(label: label, description: description)
                Spacer(minLength: 12)
                Text(percent(current))
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(Theme.mut)
            }
            Slider(value: Binding(get: { current }, set: { value = $0 }), in: 0...1, step: step)
                .tint(Theme.indigo)
                .accessibilityLabel(label)
                .accessibilityValue(percent(current))
        }
        .settingsField(label)
        .task(id: value) {
            guard let value else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let rounded = (value * 100).rounded() / 100
            if rounded != store.double(key, fallback) { store.save(key, .number(rounded)) }
            self.value = nil
        }
    }

    private func percent(_ v: Double) -> String { "\(Int((v * 100).rounded())) %" }
}
