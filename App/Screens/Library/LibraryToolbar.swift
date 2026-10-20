import SwiftUI
import FusionhaKit

/// The Library toolbar on phones (LibraryToolbar.tsx, mobile branch): Select,
/// the tier segment, the "Needs attention · N" chip, then "Filters" with its
/// badge and the grid / list segment. The row wraps the attention chip onto a
/// second line when it does not fit, as the web's flex row does. "Filters"
/// opens its panel as a popover when wide, a sheet on a phone (DC21).
struct LibraryToolbar<Filters: View>: View {
    let derived: LibraryDerived
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Binding var tier: LibraryTier
    @Binding var status: LibraryStatus
    @Binding var density: String
    /// Filters set inside the sheet (recency, group, a non-title sort).
    let filterBadge: Int
    @Binding var showingFilters: Bool
    @ViewBuilder var filters: () -> Filters

    private var attentionOn: Bool { status == .attention }
    private var showsAttention: Bool { derived.attentionCount > 0 || attentionOn }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    leading
                    if showsAttention { attentionChip }
                    Spacer(minLength: 0)
                    trailing
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        leading
                        Spacer(minLength: 0)
                        trailing
                    }
                    if showsAttention { attentionChip }
                }
            }
        }
    }

    @ViewBuilder private var leading: some View {
        GlassIconButton(systemName: model.selectMode ? "checkmark.circle.fill" : "checkmark.circle",
                        label: model.selectMode ? "Done selecting" : "Select",
                        on: model.selectMode) {
            if model.selectMode { model.exitSelectMode() } else { model.selectMode = true }
        }
        SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)
            .fixedSize()
    }

    @ViewBuilder private var trailing: some View {
        filtersChip
        densitySegment
    }

    // MARK: Needs attention

    private var attentionChip: some View {
        Button {
            withAnimation(motion ? .snappy : nil) { status = attentionOn ? .all : .attention }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 12, weight: .semibold))
                Text("Needs attention · \(derived.attentionCount)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.miss)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.miss.opacity(attentionOn ? 0.24 : 0.1)).interactive(), in: Capsule())
        .fixedSize()
        .accessibilityLabel("Needs attention · \(derived.attentionCount)")
        .accessibilityAddTraits(attentionOn ? .isSelected : [])
    }

    // MARK: Filters

    private var filtersChip: some View {
        Button { showingFilters = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mut)
                Text("Filters").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
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
        .accessibilityValue(filterBadge > 0 ? "\(filterBadge) active" : "")
        .sheetPopover(isPresented: $showingFilters, width: 380, height: 600, content: filters)
    }

    // MARK: Density

    private var densitySegment: some View {
        SegmentedIcons(options: [("grid", "square.grid.2x2", "Poster grid"), ("compact", "list.bullet", "Compact list")],
                       selection: densityBinding)
    }

    private var densityBinding: Binding<String> {
        Binding(get: { density }, set: { next in
            withAnimation(motion ? Motion.indicator : nil) { density = next }
        })
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
