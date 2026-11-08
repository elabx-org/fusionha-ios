import SwiftUI
import FusionhaKit

/// Home's sections, top to bottom (owner-approved Home mock, 2026-11-06):
/// the counts line, Needs you, Coming up, Recently added, a row per kind
/// and the All titles card. Narrow (the phone, the folded Duo, a list
/// pane) everything stacks; wide (700 and up: the open Duo, an iPad) the
/// counts sit beside Needs you as one line (`V2NeedsYouLine`), Coming up
/// spans the page (`V2ComingUpRow`), Recently added is the zipper and the
/// kinds are side-by-side columns. The sections are the anchors Home keeps
/// at its top across a fold (`foldRow`): the same ids in both layouts.
struct V2HomeContent: View {
    let data: V2HomeData
    let held: Set<Int>
    let width: CGFloat
    @Binding var comingUpArt: URL?
    let open: (V2AllTitlesEntry) -> Void
    @Environment(\.pagePalette) private var page

    private var wide: Bool { width >= 700 }
    private var gutter: CGFloat { wide ? 24 : 20 }

    var body: some View {
        if wide { wideBody } else { narrowBody }
    }

    private var stats: some View {
        V2LibraryStatsLine(derived: data.stats, kind: "all")
    }

    /// The page draws "Home" with the mark and the counts under it, at
    /// every width (`V2HomeHeading`).
    private var heading: some View { V2HomeHeading(stats: stats) }

    @ViewBuilder
    private var attention: some View {
        if !data.attention.isEmpty {
            V2NeedsAttentionRow(items: data.attention, held: held) { open(.needsYou) }
        }
    }

    private var narrowBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading.padding(.horizontal, gutter).padding(.top, 4)
                .foldRow(FoldAnchorTop.header)
            if !data.attention.isEmpty {
                attention.padding(.horizontal, gutter).padding(.top, 14)
            }
            V2ComingUpRow(width: width, gutter: gutter, wide: false, topGap: 22, leadArt: $comingUpArt)
                .foldRow("home-comingup")
            V2RecentSection(data: data, width: width, gutter: gutter, wide: false) { open(.recent(lastMonth: data.recentCount > 0)) }
                .padding(.top, 18)
                .foldRow("home-recent")
            VStack(alignment: .leading, spacing: 26) {
                ForEach(data.kinds) { kind in
                    V2KindStrip(kind: kind, gutter: gutter) { open(.kind(kind.kind)) }
                }
            }
            .padding(.top, 26)
            .foldRow("home-kinds")
            V2AllTitlesCard(data: data) { open(.everything) }
                .padding(.horizontal, gutter)
                .padding(.top, 28)
                .foldRow("home-all")
        }
    }

    private var wideBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2HomePair {
                heading
            } trailing: {
                V2NeedsYouLine(items: data.attention, held: held) { open(.needsYou) }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
            .padding(.top, 8)
            .foldRow(FoldAnchorTop.header)
            V2ComingUpRow(width: width, gutter: gutter, wide: true, topGap: 22, leadArt: $comingUpArt)
                .foldRow("home-comingup")
            V2RecentSection(data: data, width: width, gutter: gutter, wide: true) { open(.recent(lastMonth: data.recentCount > 0)) }
                .padding(.top, 26)
                .foldRow("home-recent")
            V2HomeKinds(data: data, open: open)
                .padding(.top, 30)
                .foldRow("home-kinds")
        }
        .padding(.horizontal, gutter)
    }
}
