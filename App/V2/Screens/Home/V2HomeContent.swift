import SwiftUI
import FusionhaKit

/// Home's sections, top to bottom (owner-approved Home mock, 2026-11-06):
/// the counts line, Needs you, Coming up, Recently added, a row per kind
/// and the All titles card. Narrow (the phone, the folded Duo, a list
/// pane) everything stacks; wide (700 and up: the open Duo, an iPad) the
/// counts sit beside Needs you, the carousel beside its detail, Recently
/// added is the zipper and the kinds are side-by-side columns.
struct V2HomeContent: View {
    let data: V2HomeData
    let held: Set<Int>
    let width: CGFloat
    @Binding var comingUpArt: URL?
    let open: (V2AllTitlesEntry) -> Void

    private var wide: Bool { width >= 700 }
    private var gutter: CGFloat { wide ? 24 : 20 }

    var body: some View {
        if wide { wideBody } else { narrowBody }
    }

    private var stats: some View {
        V2LibraryStatsLine(derived: data.stats, kind: "all")
    }

    @ViewBuilder
    private var attention: some View {
        if !data.attention.isEmpty {
            V2NeedsAttentionRow(items: data.attention, held: held) { open(.needsYou) }
        }
    }

    private var narrowBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            stats.padding(.horizontal, gutter)
            if !data.attention.isEmpty {
                attention.padding(.horizontal, gutter).padding(.top, 14)
            }
            V2ComingUpRow(width: width, gutter: gutter, wide: false, leadArt: $comingUpArt)
                .padding(.top, 22)
            V2RecentSection(data: data, width: width, gutter: gutter, wide: false) { open(.recent) }
                .padding(.top, 18)
                .id("home-recent")
            VStack(alignment: .leading, spacing: 26) {
                ForEach(data.kinds) { kind in
                    V2KindStrip(kind: kind, gutter: gutter) { open(.kind(kind.kind)) }
                }
            }
            .padding(.top, 26)
            .id("home-kinds")
            V2AllTitlesCard(data: data) { open(.everything) }
                .padding(.horizontal, gutter)
                .padding(.top, 28)
        }
    }

    private var wideBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2HomePair {
                stats.padding(.top, 4)
            } trailing: {
                attention
            }
            V2ComingUpRow(width: width, gutter: gutter, wide: true, leadArt: $comingUpArt)
                .padding(.top, 22)
            V2RecentSection(data: data, width: width, gutter: gutter, wide: true) { open(.recent) }
                .padding(.top, 26)
                .id("home-recent")
            V2HomeKinds(data: data, open: open)
                .padding(.top, 30)
                .id("home-kinds")
        }
        .padding(.horizontal, gutter)
    }
}
