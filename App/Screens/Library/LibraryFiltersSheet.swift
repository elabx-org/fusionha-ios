import SwiftUI
import FusionhaKit

/// A simple wrapping row (CSS `flex-wrap: wrap`).

struct LibraryWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Filters sheet

/// The "Filters" sheet: Recency, Group: Status, Sort and the coverage-rail
/// display (admins write it to Settings; others see why they can't).
struct LibraryFiltersSheet: View {
    @Environment(AppModel.self) private var model
    @Binding var recency: LibraryRecency
    @Binding var group: Bool
    @Binding var sort: LibrarySort

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Filters").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                section("Recency") {
                    SegmentedPills(options: [(LibraryRecency.all, "Any"), (.added, "Added"), (.released, "Released")],
                                   selection: $recency)
                }
                section("Group") {
                    Button {
                        group.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            if group { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                            Text("Group: Status").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(group ? Theme.i2 : Theme.txt)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(group ? Theme.i2.opacity(0.1) : Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(group ? Theme.i2 : Theme.line))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                section("Sort") {
                    Picker("Sort", selection: $sort) {
                        ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.txt)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .panel(Theme.panel2, radius: 10)
                }
                section("Coverage rails") { LibraryRailControls() }
            }
            .padding(20)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
