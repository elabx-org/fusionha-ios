import SwiftUI
import FusionhaKit

/// "All titles 843" over the grid (mock browse-lib.js `lhead`), with the sort
/// as a glass capsule menu and one grid ⇄ list button.
struct V2LibrarySectionHead: View {
    let title: String
    let count: Int
    let filters: V2LibraryFilters
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Text(count.formatted())
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .contentTransition(.numericText())
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    sortMenu
                    density
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: filters.$sort) {
                ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .semibold))
                Text(shortLabel).font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .glassControl()
        .fixedSize()
        .accessibilityLabel("Sort, \(filters.sort.label)")
    }

    private var density: some View {
        let grid = !filters.compact
        return GlassIconButton(systemName: grid ? "list.bullet" : "square.grid.2x2",
                               label: grid ? "Show as list" : "Show as poster grid", size: 34) {
            withAnimation(motion ? Motion.indicator : nil) { filters.density = grid ? "compact" : "grid" }
        }
        .sensoryFeedback(.selection, trigger: filters.density)
    }

    private var shortLabel: String {
        switch filters.sort {
        case .title: return "A–Z"
        case .yearDesc: return "Newest"
        case .yearAsc: return "Oldest"
        case .addedDesc: return "Added"
        case .releasedDesc: return "Released"
        }
    }
}
