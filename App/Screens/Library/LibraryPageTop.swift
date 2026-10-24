import SwiftUI
import FusionhaKit

/// The Library above the grid (owner-approved layout A, 2026-10-23): the
/// counts, the page filters (kind control, then quality · Filters · grid ⇄
/// list), the Recently added shelf and the "All titles" heading. Past 720 in
/// the Web layout, the web's desktop header, pulse ribbon and toolbar instead.
/// The filters sit on their own rows under the title and both the shelf and
/// the grid follow them.
struct LibraryPageTop: View {
    let derived: LibraryDerived
    let wide: Bool
    let compact: Bool
    let filterBadge: Int
    let paneWidth: CGFloat
    @Binding var kind: String
    @Binding var density: String
    @Binding var tier: LibraryTier
    @Binding var status: LibraryStatus
    @Binding var sort: LibrarySort
    @Binding var recency: LibraryRecency
    @Binding var group: Bool
    @Binding var searching: Bool
    @Binding var showingFilters: Bool
    /// Scrolls to the "All titles" heading (See all).
    let toGrid: () -> Void
    @Environment(\.motionEnabled) private var motion
    @Environment(\.spread) private var spread
    /// The kind control fell back to labels only: the counts join the summary line.
    @State private var kindCountsInSummary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            if wide {
                wideTop
            } else if spread.spans {
                spanTop
            } else {
                phoneTop
            }
            if showsShelf {
                LibraryRecentShelf(items: derived.recent, spans: spread.spans, width: paneWidth) {
                    withAnimation(motion ? .smooth(duration: 0.3) : nil) { sort = .addedDesc }
                    toGrid()
                }
                .padding(.bottom, 26)
                .reveal(3)
            }
            if !wide && !compact && derived.titleCount > 0 {
                // "All titles" follows the same page filters as the shelf.
                LibrarySectionTitle(text: "All titles")
                    .padding(.bottom, 12)
                    .id("library-grid")
                    .reveal(4)
            }
        }
    }

    /// The open Duo's list column beside a title, a third wide when flat
    /// (option A): the kind control is one menu ("All · 3,785").
    private var narrowList: Bool {
        spread.isActive && !spread.spans && DuoSplit.isNarrowList(width: Double(paneWidth))
    }

    /// Layout A's shelf: phone-sized pages with posters and something to show.
    private var showsShelf: Bool {
        !wide && !compact && !derived.recent.isEmpty && derived.titleCount > 0
    }

    /// The web's desktop Library (past 720, Web layout).
    @ViewBuilder
    private var wideTop: some View {
        LibraryHeader(derived: derived, status: $status, searching: $searching, wide: true)
            .reveal(0)
        LibraryPulseRibbon(derived: derived, status: $status, kind: $kind)
            .padding(.top, 16)
            .reveal(1)
        LibraryToolbarWide(derived: derived, tier: $tier, recency: $recency, status: $status,
                           group: $group, sort: $sort, density: $density)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .reveal(2)
    }

    /// Layout A on a phone and the closed Duo: the one-line counts, the kind
    /// control, then quality · Filters · grid ⇄ list on their own row.
    @ViewBuilder
    private var phoneTop: some View {
        LibraryHeader(derived: derived, status: $status, searching: $searching, wide: false,
                      kindCounts: kindCountsInSummary)
            .reveal(0)
        Group {
            if narrowList {
                LibraryKindMenu(derived: derived, kind: $kind)
            } else {
                LibraryKindSegment(derived: derived, kind: $kind, countsInSummary: $kindCountsInSummary)
            }
        }
        .padding(.top, 14)
        .reveal(1)
        phoneToolbar
            .padding(.top, 12)
            .padding(.bottom, 22)
            .reveal(2)
    }

    /// Layout A across the open Duo: one header over both pages. The counts on
    /// the left page; under them, on one line, the kind control on the left
    /// page and quality · Filters · grid ⇄ list on the right.
    private var spanTop: some View {
        VStack(alignment: .leading, spacing: 14) {
            LibraryHeader(derived: derived, status: $status, searching: $searching, wide: false,
                      kindCounts: kindCountsInSummary)
            FoldSpanRow(trailingAlignment: .center) {
                LibraryKindSegment(derived: derived, kind: $kind, countsInSummary: $kindCountsInSummary)
            } trailing: {
                phoneToolbar
            }
        }
        .padding(.bottom, 22)
        .reveal(0)
    }

    /// The phone's control row (tier · attention · Filters · grid ⇄ list).
    private var phoneToolbar: some View {
        LibraryToolbar(derived: derived, tier: $tier, status: $status, density: $density,
                       filterBadge: filterBadge, showingFilters: $showingFilters) {
            LibraryFiltersSheet(recency: $recency, group: $group, sort: $sort)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
    }
}
