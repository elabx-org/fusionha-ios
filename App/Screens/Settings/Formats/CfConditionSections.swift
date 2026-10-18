import SwiftUI
import FusionhaKit

/// The condition-block builder (web `CfConditionBlocks`): the flat
/// specification list shown grouped by spec type — OR within a block
/// ("any of N"), AND between blocks. Each condition has is / is not, its
/// value (enum picker or regex field), a ★ required toggle and remove; each
/// block offers "add option", and the menu appends a new block.
struct CfConditionSections: View {
    @Binding var specs: [CustomFormatSpec]

    var body: some View {
        let blocks = CFBlocks.group(specs)
        ForEach(blocks.indices, id: \.self) { bi in
            block(blocks[bi], first: bi == 0)
        }
        Section {
            Menu {
                ForEach(CFSpecVocab.types, id: \.value) { t in
                    Button("\(t.icon)  \(t.label)") { specs.append(CFSpecVocab.newSpec(t.value)) }
                }
            } label: {
                Label("Add condition block", systemImage: "plus")
            }
        }
        .listRowBackground(Theme.card)
    }

    /// A bounds-checked binding, so a row being removed never reads past the end.
    private func binding(_ index: Int, _ type: String) -> Binding<CustomFormatSpec> {
        Binding(
            get: { specs.indices.contains(index) ? specs[index] : CFSpecVocab.newSpec(type) },
            set: { if specs.indices.contains(index) { specs[index] = $0 } }
        )
    }

    private func block(_ block: CFBlock, first: Bool) -> some View {
        let label = CFSpecVocab.label(block.type)
        return Section {
            ForEach(Array(block.indices.enumerated()), id: \.element) { pair in
                CfConditionRow(spec: binding(pair.element, block.type), blockLabel: label, n: pair.offset + 1) {
                    if specs.indices.contains(pair.element) { specs.remove(at: pair.element) }
                }
            }
            Button("add ‘\(label)’ option", systemImage: "plus") { specs = CFBlocks.addToBlock(specs, block) }
                .font(.system(size: 13))
        } header: {
            HStack(spacing: 6) {
                if !first { Text("AND").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.i2) }
                Text(CFSpecVocab.icon(block.type)).foregroundStyle(Theme.dim)
                Text(label).textCase(nil)
                if block.indices.count > 1 {
                    Text("any of \(block.indices.count)").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.i2).textCase(nil)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(first ? "" : "And, ")\(label) condition block")
        }
        .listRowBackground(Theme.card)
    }
}

/// One condition: is / is not · value · ★ required · remove.
private struct CfConditionRow: View {
    @Binding var spec: CustomFormatSpec
    let blockLabel: String
    let n: Int
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(spec.negate ? "is not" : "is") { spec.negate.toggle() }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(spec.negate ? Theme.danger : Theme.mut)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .glassEffect(.regular.interactive(), in: Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel("Negate \(blockLabel) condition \(n)")
                .accessibilityAddTraits(spec.negate ? .isSelected : [])
            value
            Button { spec.required.toggle() } label: {
                Image(systemName: spec.required ? "star.fill" : "star")
                    .foregroundStyle(spec.required ? Theme.miss : Theme.dim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Required \(blockLabel) condition \(n)")
            .accessibilityHint("Required — must match even within its block")
            .accessibilityAddTraits(spec.required ? .isSelected : [])
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.dim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(blockLabel) condition \(n)")
        }
    }

    @ViewBuilder
    private var value: some View {
        if let options = CFSpecVocab.options(for: spec.specType) {
            Picker("\(blockLabel) condition \(n) value", selection: $spec.value) {
                // A stored value outside the vocabulary still shows as itself.
                if !options.contains(where: { $0.value == spec.value }) { Text(spec.value).tag(spec.value) }
                ForEach(options, id: \.value) { o in Text(o.label).tag(o.value) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.txt)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField("regex pattern", text: $spec.value)
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("\(blockLabel) condition \(n) value")
                .frame(maxWidth: .infinity)
        }
    }
}
