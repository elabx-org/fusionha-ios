import SwiftUI
import FusionhaKit

/// A length of time in Settings (owner-approved number controls, 2026-11-08):
/// a native menu of presets that suit this setting, the current value ticked,
/// then Custom… for the duration wheel. The server keeps its own key and unit;
/// presets are plain seconds converted on save.
struct SettingDuration: View {
    @Environment(SettingsStore.self) private var store
    let key: String
    let label: String
    var description: String?
    /// The unit the server stores this key in.
    let unit: DurationUnit
    /// Menu presets, in seconds.
    let presets: [Double]
    /// Shown for 0 ("Off", "Never"), which is then offered first.
    var zero: String?
    /// The server's safe floor and ceiling, in seconds.
    var floor: Double?
    var ceiling: Double?
    /// The custom sheet's wheels, largest first.
    var columns: [DurationUnit] = [.days, .hours, .minutes]
    var fallback: Double = 0
    var disabled = false
    @State private var custom = false

    private var seconds: Double { store.double(key, fallback) * unit.rawValue }

    var body: some View {
        LabeledContent {
            Menu {
                Picker(selection: Binding(get: { seconds }, set: save)) {
                    ForEach(options, id: \.self) { s in
                        Text(title(s)).tag(s)
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)
                Divider()
                Button("Custom…") { custom = true }
            } label: {
                HStack(spacing: 5) {
                    Text(title(seconds)).monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 15))
                .foregroundStyle(disabled ? Theme.dim : Theme.mut)
            }
            .accessibilityLabel(label)
            .accessibilityValue(spoken(seconds))
        } label: {
            FieldLabel(label: label, description: description)
        }
        .disabled(disabled)
        .settingsField(label)
        .sheet(isPresented: $custom) {
            DurationWheelSheet(label: label, description: description, seconds: seconds,
                               columns: columns, zero: zero, floor: floor, ceiling: ceiling, onSave: save)
        }
    }

    /// The presets, plus the current value when it isn't one of them, so the
    /// tick always shows where the setting is.
    private var options: [Double] {
        var all = presets.filter { s in (floor.map { s >= $0 } ?? true) && (ceiling.map { s <= $0 } ?? true) }
        if zero != nil, !all.contains(0) { all.insert(0, at: 0) }
        if !all.contains(seconds) { all.append(seconds) }
        return all.sorted()
    }

    private func title(_ s: Double) -> String {
        if s == 0, let zero { return zero }
        return DurationFormat.short(s)
    }

    private func spoken(_ s: Double) -> String {
        if s == 0, let zero { return zero }
        return DurationFormat.long(s)
    }

    private func save(_ s: Double) {
        var next = s
        if let floor, next != 0 || zero == nil { next = max(floor, next) }
        if let ceiling { next = min(ceiling, next) }
        let stored = (next / unit.rawValue).rounded()
        if stored != store.double(key, fallback) { store.save(key, .number(stored)) }
    }
}
