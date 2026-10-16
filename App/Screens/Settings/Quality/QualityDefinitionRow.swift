import SwiftUI
import FusionhaKit

/// One quality's size window: the draggable min · preferred · max bar, the
/// typed min – max MB/min fields (blank max = unlimited) and the ≈ file size
/// for the preview runtime. Holds its own working values while editing and
/// re-syncs from the server row when it is not being dragged.
struct QualityDefinitionRow: View {
    let def: QualityDefinitionRecord
    let runtime: Int
    let onCommit: (QualitySizeRange) -> Void
    @State private var range: QualitySizeRange
    @State private var dragging = false

    init(def: QualityDefinitionRecord, runtime: Int, onCommit: @escaping (QualitySizeRange) -> Void) {
        self.def = def
        self.runtime = runtime
        self.onCommit = onCommit
        _range = State(initialValue: QualitySizeRange(def))
    }

    var body: some View {
        let label = QualityLadder.label(def.quality)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 8)
                Text(QualitySizeLimits.fileSizeLine(range, runtime: runtime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.mut)
            }
            QualityDefinitionRangeBar(label: label, range: $range, dragging: $dragging) { onCommit(range) }
            HStack(spacing: 6) {
                Text("MB / min").font(.caption).foregroundStyle(Theme.dim)
                Spacer(minLength: 0)
                QualityDefinitionSizeField(label: "\(label) minimum MB per minute", value: range.min) { v in
                    commit(QualitySizeLimits.typedMin(range, v))
                }
                Text("–").foregroundStyle(Theme.dim)
                QualityDefinitionSizeField(label: "\(label) maximum MB per minute",
                                           value: range.unlimited ? nil : range.max, placeholder: "∞") { v in
                    commit(QualitySizeLimits.typedMax(range, v))
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: QualitySizeRange(def)) {
            if !dragging { range = QualitySizeRange(def) }
        }
    }

    private func commit(_ next: QualitySizeRange) {
        range = next
        onCommit(next)
    }
}

/// A small MB/min field: free text while focused; Return or blur parses it.
/// Blank or non-numeric means nil (max → unlimited, min → 0).
struct QualityDefinitionSizeField: View {
    let label: String
    let value: Double?
    var placeholder = ""
    let onCommit: (Double?) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: $text, prompt: Text(placeholder))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 7)
            .frame(width: 58, height: 28)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(focused ? Theme.indigo : Theme.line, lineWidth: 1))
            .focused($focused)
            .onSubmit(commit)
            .onAppear { text = Self.format(value) }
            .onChange(of: value) { if !focused { text = Self.format(value) } }
            .onChange(of: focused) { if !focused { commit() } }
            .accessibilityLabel(label)
    }

    private static func format(_ v: Double?) -> String {
        guard let v else { return "" }
        return String(Int(v.rounded()))
    }

    private func commit() {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if t.isEmpty || t == "∞" { onCommit(nil); return }
        if let v = Double(t), v.isFinite, v >= 0 { onCommit(v) } else { onCommit(nil) }
    }
}
