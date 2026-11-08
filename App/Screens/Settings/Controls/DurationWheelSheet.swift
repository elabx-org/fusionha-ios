import SwiftUI
import FusionhaKit

/// Custom… on a duration row: the setting's description, one native wheel per
/// unit, and the value spelled out. Done saves; values under the server's
/// floor are raised to it, and the footer says so before you tap.
struct DurationWheelSheet: View {
    let label: String
    var description: String?
    let seconds: Double
    let columns: [DurationUnit]
    var zero: String?
    var floor: Double?
    var ceiling: Double?
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var parts: [Int] = []

    private var picked: Double { DurationFormat.seconds(parts, columns: columns) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mut)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if parts.count == columns.count {
                    HStack(spacing: 0) {
                        ForEach(columns.indices, id: \.self) { i in wheel(i) }
                    }
                    .frame(height: 216)
                }
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(picked)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { parts = DurationFormat.parts(seconds, columns: columns) }
    }

    private func wheel(_ i: Int) -> some View {
        HStack(spacing: 4) {
            Picker(columns[i].short, selection: $parts[i]) {
                ForEach(0..<range(i), id: \.self) { n in
                    Text("\(n)").monospacedDigit().tag(n)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            Text(columns[i].short)
                .font(.system(size: 15))
                .foregroundStyle(Theme.txt)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    /// The first wheel reaches the ceiling (or a sensible span); the rest
    /// wrap at their natural carry.
    private func range(_ i: Int) -> Int {
        let unit = columns[i]
        guard i == 0 else { return unit.carry }
        let span = ceiling ?? (unit == .days ? 400 * 86400 : unit.rawValue * Double(unit == .hours ? 168 : 120))
        return max(Int(span / unit.rawValue) + 1, parts.first.map { $0 + 1 } ?? 1)
    }

    private var footer: String {
        let s = picked
        if s == 0, let zero { return zero }
        if let floor, s < floor { return "The server won't go below \(DurationFormat.long(floor)), so this saves as \(DurationFormat.long(floor))." }
        if let ceiling, s > ceiling { return "The most this can be is \(DurationFormat.long(ceiling))." }
        return DurationFormat.long(s)
    }
}
