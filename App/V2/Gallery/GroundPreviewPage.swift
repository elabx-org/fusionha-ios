import SwiftUI
import FusionhaKit

/// The Ground preview's sample page: a heading in the page ink, a captioned
/// module with hairline rows, a held module and a plain card, all on the
/// ground the preview puts behind it.
struct GroundPreviewPage: View {
    let item: MediaItem?
    let recipe: PageGround.Recipe
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            WidgetModule(caption: "Today", systemImage: "arrow.down") {
                Text("2 of 3").monospacedDigit()
            } content: {
                ForEach(GroundPreviewPage.rows) { row in
                    rowView(row)
                }
            }
            WidgetModule(caption: "Needs you", systemImage: "pause.fill", needsYou: true) {
                rowView(GroundPreviewPage.held)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("A plain card").font(.subheadline.weight(.semibold)).foregroundStyle(ink)
                Text("Frosted material, a hairline light edge on top, one soft shadow, 22pt corners.")
                    .font(.footnote)
                    .foregroundStyle(muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .v2CardStyle()
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item?.title ?? "No art")
                .font(.title2.weight(.bold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(muted)
        }
    }

    private var subtitle: String {
        let ground = page?.fromArt == true ? "Art palette ground" : "Tint ground"
        return recipe == .page ? ground : "\(ground) · list pane"
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.subheadline.weight(.semibold)).foregroundStyle(ink).lineLimit(1)
                Text(row.meta).font(.caption).foregroundStyle(muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            EditionTicketPair(hd: row.hd, uhd: row.uhd)
        }
    }

    struct Row: Identifiable {
        let title: String
        let meta: String
        let hd: EditionBadgeState?
        let uhd: EditionBadgeState?
        var id: String { title }
    }

    static let rows: [Row] = [
        Row(title: "Both on disk", meta: "Movie · 2025", hd: .onDisk, uhd: .onDisk),
        Row(title: "4K downloading", meta: "Movie · 2024 · 62%", hd: .onDisk, uhd: .downloading(progress: 0.62)),
        Row(title: "Both missing", meta: "Series · S2 · 3 of 8", hd: .missing, uhd: .missing),
    ]

    static let held = Row(title: "Held for you", meta: "Movie · 2025 · pick a release", hd: .held, uhd: .missing)
}
