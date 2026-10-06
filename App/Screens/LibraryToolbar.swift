import SwiftUI
import FusionhaKit

/// The Library toolbar (LibraryToolbar mobile branch): select · tier ·
/// attention · Filters, then the grid / list density toggle.
struct LibraryToolbar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Binding var tier: LibraryTier
    @Binding var status: LibraryStatus
    @Binding var density: String
    let attentionCount: Int
    /// Filters set inside the sheet (recency, group, a non-title sort).
    let filterBadge: Int
    let openFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryToolbarRow(spacing: 10) {
                Button {
                    if model.selectMode { model.exitSelectMode() } else { model.selectMode = true }
                } label: {
                    Image(systemName: model.selectMode ? "checkmark.square" : "viewfinder")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(model.selectMode ? Theme.i2 : Theme.mut)
                        .frame(width: 38, height: 38)
                        .background(model.selectMode ? Theme.i2.opacity(0.10) : Theme.panel,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(model.selectMode ? Theme.i2 : Theme.line))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(model.selectMode ? "Exit select mode" : "Select titles")

                SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)

                if attentionCount > 0 || status == .attention {
                    Button {
                        withAnimation(motion ? .snappy : nil) { status = status == .attention ? .all : .attention }
                    } label: {
                        Text("Needs attention · \(attentionCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.miss)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(Theme.miss.opacity(status == .attention ? 0.2 : 0.12),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.miss.opacity(status == .attention ? 0.7 : 0.4)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            } trailing: {
                Button { openFilters() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.mut)
                        Text("Filters").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                        if filterBadge > 0 {
                            Text("\(filterBadge)")
                                .font(.system(size: 10.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 17, minHeight: 17)
                                .background(Theme.fusion, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .panel(Theme.panel, radius: 10)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.bottom, 20)

            densityToggle
                .padding(.bottom, 20)
        }
    }

    /// Grid / list toggle: 34×30 buttons in a `--panel` track.
    private var densityToggle: some View {
        HStack(spacing: 0) {
            ForEach(["grid", "compact"], id: \.self) { value in
                let active = density == value
                Button {
                    withAnimation(motion ? Motion.indicator : nil) { density = value }
                } label: {
                    Image(systemName: value == "grid" ? "square.grid.2x2" : "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? Theme.segActiveText : Theme.mut)
                        .frame(width: 34, height: 30)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.indigo.opacity(0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Theme.indigo.opacity(0.55)))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == "grid" ? "Grid view" : "List view")
            }
        }
        .padding(3)
        .panel(Theme.panel, radius: 10)
        .sensoryFeedback(.selection, trigger: density)
    }
}

/// Lays out the toolbar's left group with a trailing control pinned right,
/// wrapping the left group like the web's `flex-wrap` row.
private struct LibraryToolbarRow<Leading: View, Trailing: View>: View {
    var spacing: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                leading
                Spacer(minLength: 0)
                trailing
            }
            VStack(alignment: .leading, spacing: spacing) {
                HStack(spacing: spacing) {
                    leading
                }
                HStack {
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
    }
}
