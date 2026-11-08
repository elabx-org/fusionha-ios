import SwiftUI
import FusionhaKit

// The v2 form sheet (Look Pass family 1, owner-approved 2026-11-08): the
// title sheets (Rename, Edition aliases, Fix numbering, Metadata switch,
// Report an issue, Add collection, Import loose files) share one look. A
// large left-aligned title with a muted subline in the body, then solid
// inset-grouped cards with hairlines under sentence-case labels. The glass
// xmark and the accent capsule are the sheets' own toolbar items.

enum V2Form {
    static let radius: CGFloat = 20
    static let rowInset: CGFloat = 16
}

/// The sheet's heading: large title, left aligned, one muted line under it.
struct V2SheetHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

/// A sentence-case section label, with an optional quiet hint on the right.
struct V2FormLabel: View {
    let text: String
    var hint: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let hint {
                Text(hint).font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// One solid inset-grouped card: content, never glass.
struct V2FormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: V2Form.radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: V2Form.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: V2Form.radius, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 0.5))
    }
}

/// A label, its card, and an optional footer line under the card.
struct V2FormSection<Content: View>: View {
    let label: String?
    var hint: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let label { V2FormLabel(text: label, hint: hint) }
            V2FormCard { content }
            if let footer {
                Text(footer)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// The hairline between two rows of a card, inset like a grouped list.
struct V2FormDivider: View {
    var inset: CGFloat = V2Form.rowInset

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

extension View {
    /// The padding of one row in a `V2FormCard`.
    func v2FormRow(vertical: CGFloat = 12) -> some View {
        self
            .padding(.horizontal, V2Form.rowInset)
            .padding(.vertical, vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row with a label on the left and a native menu picker on the right.
struct V2FormPickerRow<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    @ViewBuilder var options: Options

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 16)).foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) { options }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.mut)
        }
        .padding(.leading, V2Form.rowInset)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .frame(minHeight: 48)
    }
}

/// A mono, selectable file path.
struct V2FormPath: View {
    let path: String
    var color: Color = Theme.txt

    var body: some View {
        Text(path)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
