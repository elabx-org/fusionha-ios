import SwiftUI

/// A W1 module (mock cards-w.js): a section caption and its rows in ONE
/// frosted card, the caption inside it and the rows split by hairlines
/// instead of stacked bordered boxes.
struct WidgetModule<Trailing: View, Content: View>: View {
    let caption: String
    var systemImage: String?
    /// Orange caption: the section needs the owner (held items).
    var needsYou = false
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                }
                Text(caption)
                Spacer(minLength: 8)
                trailing()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(needsYou ? Theme.stuck : (page?.inkMuted ?? Theme.mut))
            .accessibilityAddTraits(.isHeader)
            ModuleRows(content: content)
        }
        .padding(ModuleMetrics.moduleInsets)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface() }
    }
}

extension WidgetModule where Trailing == EmptyView {
    init(caption: String, systemImage: String? = nil, needsYou: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(caption: caption, systemImage: systemImage, needsYou: needsYou,
                  trailing: { EmptyView() }, content: content)
    }
}

/// Rows split by hairlines, each with the module's row padding.
struct ModuleRows<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let hairline = ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight)
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content()) { rows in
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    row
                        .padding(.vertical, ModuleMetrics.rowPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) {
                            if index > 0 {
                                hairline.frame(height: EditionChip.hairline(displayScale))
                            }
                        }
                }
            }
        }
    }
}
