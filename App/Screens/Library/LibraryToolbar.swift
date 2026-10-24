import SwiftUI
import FusionhaKit

/// The Library's second control row on phones (owner-approved layout A): the
/// All | HD | 4K segment, the "Needs attention · N" chip when there is any,
/// then "Filters" with its badge and one grid ⇄ list round button. Select
/// moved to the bar. The row wraps the attention chip onto a
/// second line when it does not fit, as the web's flex row does. "Filters"
/// opens its panel as a popover when wide, a sheet on a phone (DC21).
struct LibraryToolbar<Filters: View>: View {
    let derived: LibraryDerived
    @Environment(\.motionEnabled) private var motion
    @Binding var tier: LibraryTier
    @Binding var status: LibraryStatus
    @Binding var density: String
    /// Filters set inside the sheet (recency, group, a non-title sort).
    let filterBadge: Int
    @Binding var showingFilters: Bool
    @ViewBuilder var filters: () -> Filters

    private var showsAttention: Bool { derived.attentionCount > 0 || status == .attention }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            // One row whenever it can be (a Spread's right page lines up with
            // the kind control on the left): the attention chip shortens to
            // its glyph and count, then Filters to its glyph, before the chip
            // wraps onto a second line.
            ViewThatFits(in: .horizontal) {
                row(compactChip: false, iconFilters: false)
                if showsAttention {
                    row(compactChip: true, iconFilters: false)
                    row(compactChip: true, iconFilters: true)
                } else {
                    // The flat Duo's third-wide list (option A): Filters as its glyph.
                    row(compactChip: false, iconFilters: true)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        leading
                        Spacer(minLength: 0)
                        trailing(iconFilters: true)
                    }
                    if showsAttention { LibraryAttentionChip(count: derived.attentionCount, status: $status) }
                }
            }
        }
    }

    private func row(compactChip: Bool, iconFilters: Bool) -> some View {
        HStack(spacing: 8) {
            leading
            if showsAttention {
                LibraryAttentionChip(count: derived.attentionCount, status: $status, compact: compactChip)
            }
            Spacer(minLength: 0)
            trailing(iconFilters: iconFilters)
        }
    }

    @ViewBuilder private var leading: some View {
        SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)
            .fixedSize()
    }

    @ViewBuilder private func trailing(iconFilters: Bool) -> some View {
        filtersChip(iconOnly: iconFilters)
        densityButton
    }

    // MARK: Filters

    private func filtersChip(iconOnly: Bool) -> some View {
        Button { showingFilters = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mut)
                if !iconOnly {
                    Text("Filters").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                }
                if filterBadge > 0 {
                    Text("\(filterBadge)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.onAccent)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Theme.primary, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl(on: filterBadge > 0)
        .fixedSize()
        .accessibilityLabel("Filters")
        .accessibilityValue(filterBadge > 0 ? "\(filterBadge) active" : "")
        .sheetPopover(isPresented: $showingFilters, width: 380, height: 600, content: filters)
    }

    // MARK: Density

    /// One round button that shows the other view: the list glyph on the
    /// grid, the grid glyph on the list.
    private var densityButton: some View {
        let grid = density != "compact"
        return GlassIconButton(systemName: grid ? "list.bullet" : "square.grid.2x2",
                               label: grid ? "Show as list" : "Show as poster grid") {
            withAnimation(motion ? Motion.indicator : nil) { density = grid ? "compact" : "grid" }
        }
        .sensoryFeedback(.selection, trigger: density)
    }
}

/// A two-or-more segment glass control of glyphs (the web's `.vt` toggle).
struct SegmentedIcons: View {
    let options: [(String, String, String)]
    @Binding var selection: String
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option in
                let (value, symbol, label) = option
                let on = value == selection
                Button { selection = value } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(on ? Theme.txt : Theme.mut)
                        .frame(width: 34, height: 30)
                        .background {
                            if on {
                                Capsule().fill(Theme.txt.opacity(0.14))
                                    .matchedGeometryEffect(id: "seg", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}
