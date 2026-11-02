import SwiftUI
import FusionhaKit

/// "Requested by Sam + 2" in the hero (RequestedByPill.tsx): up to three
/// askers' faces, oldest first; a tap scrolls to the request strip.
struct RequestedByPill: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model

    var body: some View {
        let rows = store.requestRows.filter { $0.request.status != "withdrawn" }
        if model.me != nil, !model.requestScoped, let oldest = rows.last {
            let requests = rows.map(\.request)
            let others = RequestItemStrip.askerCount(requests) - 1
            Button { store.revealRequests += 1 } label: {
                HStack(spacing: 8) {
                    HStack(spacing: -8) {
                        ForEach(Array(faces(rows).enumerated()), id: \.offset) { _, person in
                            PersonAvatar(userId: person?.id ?? 0, name: person?.displayName ?? "?",
                                         hasThumb: person?.avatar != nil, size: 22)
                        }
                    }
                    (Text("Requested by ") + Text(TriageFacts.requesterName(oldest.request)).bold()
                        + Text(others > 0 ? " + \(others)" : ""))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .frame(minHeight: 32)
                .background(Theme.bg.opacity(0.8), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
            }
            .buttonStyle(DetailPressStyle())
            .accessibilityHint("Shows the requests for this title")
        }
    }

    /// Up to three distinct askers, oldest first (rows are newest first).
    private func faces(_ rows: [ItemRequestRow]) -> [RequestPerson?] {
        var seen = Set<Int>()
        var out: [RequestPerson?] = []
        for row in rows.reversed() {
            let key = row.request.userId ?? -row.request.id
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(row.request.requester)
            if out.count == 3 { break }
        }
        return out
    }
}

/// The instant-open shell (MobileDetailFlyout `loading`): the hero drawn from
/// what the tapped poster already knew (art, title, year), else placeholder
/// bars, over the body skeleton (DetailBodySkeleton). It already stands on
/// the loaded page's backdrop (`DetailHeroBackdrop`, no hard edge) with the
/// title in white on the art's darkened edge, where the loaded title lands.
/// The shimmer stops under Reduce Motion.
struct DetailLoadingShell: View {
    let seed: MediaItem?
    @State private var edge: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .containerRelativeFrame(.vertical) { length, _ in DetailHeroArt.height(for: length) }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomLeading) {
                    title
                        .padding(.horizontal, Theme.pageGutter)
                        .padding(.bottom, 18)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { edge = $0 }
            VStack(alignment: .leading, spacing: 12) {
                textLines([1, 0.7])
                HStack(spacing: 8) { ForEach(0..<4, id: \.self) { _ in SkeletonBar(height: 36, radius: 18) } }
                SkeletonBar(height: 120, radius: 20).padding(.top, 10)
                HStack(spacing: 14) { ForEach(0..<3, id: \.self) { _ in SkeletonBar(height: 16).frame(width: 70) } }
                    .padding(.top, 10)
                ForEach(0..<3, id: \.self) { _ in SkeletonBar(height: 52, radius: 12) }
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(alignment: .top) {
            DetailHeroBackdrop(url: ItemDetailArt.hero(backdrop: seed?.backdropUrl, poster: seed?.posterUrl),
                               layout: HeroBackdropLayout(edge: edge, handover: edge + 54, foot: edge + 240))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading title")
    }

    /// The title and meta placeholder on the art's edge, white as on the hero.
    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let seed {
                (Text(seed.title).foregroundColor(Theme.onScrim)
                    + Text(verbatim: seed.year.map { " " + String($0) } ?? "")
                        .font(Theme.display(56, semibold: true))
                        .foregroundColor(Theme.onScrim.opacity(0.6)))
                    .font(Theme.display(56))
                    .tracking(Theme.displayTracking(56))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                SkeletonBar(height: 40, radius: 10).frame(maxWidth: 260)
            }
            SkeletonBar(height: 14).frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textLines(_ lines: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { i in
                GeometryReader { geo in SkeletonBar(height: 12).frame(width: geo.size.width * lines[i]) }.frame(height: 12)
            }
        }
        .padding(.top, 8)
    }
}

/// The load failure (ItemDetail.tsx `detail-error`): the web's copy, with a
/// way back to the library.
struct DetailLoadError: View {
    let close: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("That title could not be found. Head back to your library.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
            Button("Back to library", systemImage: "chevron.left", action: close)
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 140)
    }
}
