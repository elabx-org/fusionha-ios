import SwiftUI
import FusionhaKit

/// The Library toolbar past 720 of the Library's own width (LibraryToolbar.tsx,
/// desktop branch; ruling L17): Select, the tier and recency segments, then the
/// "Needs attention · N" chip, Group: Status, the sort menu, the grid / list
/// segment and Display options (coverage rails). Everything the phone keeps in
/// its Filters sheet is inline. When the row doesn't fit, the attention chip,
/// Group and the sort wrap to a second line. The search stays the header's
/// filter field (it is the type-to-filter target on both layouts). With the
/// iPhone Duo's fold through it, the row is two pieces meeting at the gutter.
struct LibraryToolbarWide: View {
    let derived: LibraryDerived
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Binding var tier: LibraryTier
    @Binding var recency: LibraryRecency
    @Binding var status: LibraryStatus
    @Binding var group: Bool
    @Binding var sort: LibrarySort
    @Binding var density: String
    @State private var showingDisplay = false

    private var showsAttention: Bool { derived.attentionCount > 0 || status == .attention }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            // The iPhone Duo's fold through the row (Web layout): Select and the
            // segments before the gutter, the rest after it, wrapping there.
            FoldSplit(piece: .toolbar) {
                oneRow
            } leading: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { leading }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            selectButton
                            tierPills
                        }
                        recencyPills
                    }
                }
            } trailing: {
                LibraryWrap(spacing: 8) {
                    if showsAttention { LibraryAttentionChip(count: derived.attentionCount, status: $status) }
                    groupToggle
                    sortMenu
                    trailing
                }
            }
        }
    }

    /// The web's row; the attention chip, Group and the sort wrap to a second
    /// line when it doesn't fit.
    private var oneRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                leading
                Spacer(minLength: 8)
                if showsAttention { LibraryAttentionChip(count: derived.attentionCount, status: $status) }
                groupToggle
                sortMenu
                trailing
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    leading
                    Spacer(minLength: 8)
                    trailing
                }
                HStack(spacing: 8) {
                    if showsAttention { LibraryAttentionChip(count: derived.attentionCount, status: $status) }
                    Spacer(minLength: 0)
                    groupToggle
                    sortMenu
                }
            }
        }
    }

    @ViewBuilder private var leading: some View {
        selectButton
        tierPills
        recencyPills
    }

    private var selectButton: some View {
        GlassIconButton(systemName: model.selectMode ? "checkmark.circle.fill" : "checkmark.circle",
                        label: model.selectMode ? "Done selecting" : "Select",
                        on: model.selectMode) {
            if model.selectMode { model.exitSelectMode() } else { model.selectMode = true }
        }
    }

    private var tierPills: some View {
        SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)
            .fixedSize()
            .accessibilityLabel("Filter by tier")
    }

    private var recencyPills: some View {
        SegmentedPills(options: [(LibraryRecency.all, "Any"), (.added, "Added"), (.released, "Released")],
                       selection: $recency)
            .fixedSize()
            .accessibilityLabel("Filter by recency")
    }

    @ViewBuilder private var trailing: some View {
        SegmentedIcons(options: [("grid", "square.grid.2x2", "Poster grid"), ("compact", "list.bullet", "Compact list")],
                       selection: Binding(get: { density }, set: { next in
                           withAnimation(motion ? Motion.indicator : nil) { density = next }
                       }))
        displayButton
    }

    /// `Group: Status`, with a tick while on.
    private var groupToggle: some View {
        Button {
            withAnimation(motion ? .snappy : nil) { group.toggle() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: group ? "checkmark" : "square.stack.3d.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text("Group: Status").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(group ? Theme.txt : Theme.mut)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl(on: group)
        .fixedSize()
        .accessibilityLabel("Group by status")
        .accessibilityAddTraits(group ? .isSelected : [])
    }

    /// The sort select, as a native menu.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Text(sort.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl()
        .fixedSize()
        .accessibilityLabel("Sort, \(sort.label)")
    }

    /// Display options: the coverage-rail style and Consolidate (`displayPop`).
    private var displayButton: some View {
        GlassIconButton(systemName: "slider.horizontal.3", label: "Display options", on: showingDisplay) {
            showingDisplay = true
        }
        .sheetPopover(isPresented: $showingDisplay, width: 380, height: 520) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Display options").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    LibraryRailControls()
                }
                .padding(20)
            }
            .presentationBackground(Theme.panel)
        }
    }
}

/// "Needs attention · N" (#113): present only while the view holds flagged
/// titles (or the filter is on); toggles the `attention` status filter.
struct LibraryAttentionChip: View {
    let count: Int
    @Binding var status: LibraryStatus
    /// The warning glyph and the count only (a narrow row keeps it on one line).
    var compact = false
    @Environment(\.motionEnabled) private var motion

    private var on: Bool { status == .attention }

    var body: some View {
        Button {
            withAnimation(motion ? .snappy : nil) { status = on ? .all : .attention }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 12, weight: .semibold))
                Text(compact ? "\(count)" : "Needs attention · \(count)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.miss)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.miss.opacity(on ? 0.24 : 0.1)).interactive(), in: Capsule())
        .fixedSize()
        .accessibilityLabel("Needs attention · \(count)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
