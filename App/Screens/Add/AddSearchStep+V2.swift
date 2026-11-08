import SwiftUI
import FusionhaKit

/// One result ready for v2's grid or list, whichever source it came from.
struct V2AddEntry: Identifiable {
    let card: AddResultCard
    let pick: () -> Void
    let preview: (() -> Void)?
    var id: String { card.id }
}

// Add › Find in v2 (owner-approved Add results mock, 2026-11-08): TMDB and
// TVDB share the results header, the grid (Library cards) and the list (the
// v2 list surface); the source is named once, by its mark in the header.
extension AddTitleSheet {
    /// A TMDB result as the shared card, with the library title it already is.
    func card(_ result: MediaSearchResult) -> AddResultCard {
        let owned = result.inLibrary || result.libraryItemId != nil ? model.libraryItemId(for: result) : nil
        return AddResultCard(result, libraryItemId: owned)
    }

    /// Close on its own line above the title (the toolbar's Close sat on
    /// "Add title" on the folded Duo, IMG_7893).
    var v2CloseRow: some View {
        SheetCancelButton(title: "Close") { dismiss() }
            .labelStyle(.iconOnly)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 44, height: 44)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.top, 6)
    }

    /// "Results 20", the source's mark, and the grid / list switch for both sources.
    var v2SectionRow: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(term.isEmpty ? "Trending this week" : "Results")
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let count = sectionCount {
                    Text("\(count)").font(.system(size: 15).monospacedDigit()).foregroundStyle(Theme.mut)
                }
            }
            Spacer(minLength: 6)
            if !term.isEmpty {
                ProviderMark(provider: source == .tvdb ? "tvdb" : "tmdb", size: 11)
                    .accessibilityLabel(source == .tvdb ? "From TVDB" : "From TMDB")
            }
            Picker("View", selection: Binding(get: { gridView }, set: { grid in
                withAnimation(motion ? Motion.indicator : nil) { gridView = grid }
            })) {
                Image(systemName: "square.grid.2x2").accessibilityLabel("Grid view").tag(true)
                Image(systemName: "list.bullet").accessibilityLabel("List view").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 92)
        }
        .padding(.top, 8)
    }

    /// The results in the chosen view.
    @ViewBuilder
    func v2Results(_ entries: [V2AddEntry]) -> some View {
        if let look {
            if gridView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: look.tileWidth.lowerBound, maximum: look.tileWidth.upperBound),
                                             spacing: 14, alignment: .top)], spacing: 18) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        look.tile(entry.card, entry.pick, entry.preview)
                            .reveal(index, y: 10, duration: 0.4)
                    }
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        look.row(entry.card, index == 0, index == entries.count - 1, entry.pick, entry.preview)
                    }
                }
            }
        }
    }
}
