import SwiftUI
import FusionhaKit

// The release timeline (movies) and the DetailRailStack: trailer, collection,
// more like this and cast. Plus the movie Collection tab.

struct ReleaseTimeline: View {
    let detail: ItemDetail

    private struct Step: Hashable {
        let kind: String
        let date: Date
        let estimated: Bool
    }

    static func hasData(_ detail: ItemDetail) -> Bool {
        detail.inCinemas != nil || detail.digitalRelease != nil || detail.physicalRelease != nil
            || !(detail.releaseWindows ?? []).isEmpty
    }

    private var steps: [Step] {
        var byKind: [String: Step] = [:]
        for w in detail.releaseWindows ?? [] {
            guard let kind = w.kind, let date = DetailText.instant(w.date) else { continue }
            byKind[kind] = Step(kind: kind, date: date, estimated: w.estimated ?? false)
        }
        for (kind, raw) in [("cinema", detail.inCinemas), ("digital", detail.digitalRelease), ("physical", detail.physicalRelease)] {
            if let date = DetailText.instant(raw) { byKind[kind] = Step(kind: kind, date: date, estimated: false) }
        }
        return ["cinema", "digital", "physical"].compactMap { byKind[$0] }
    }

    var body: some View {
        let steps = steps
        let now = Date()
        HStack(alignment: .top, spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                let step = steps[i]
                let past = step.date <= now
                let color = past ? Theme.done : Theme.unaired
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Image(systemName: icon(step.kind))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color)
                            .frame(width: 26, height: 26)
                            .background(color.opacity(0.14), in: Circle())
                            .overlay(Circle().strokeBorder(color.opacity(0.4)))
                        if i < steps.count - 1 {
                            Rectangle().fill(past ? Theme.done.opacity(0.5) : Theme.line).frame(height: 2)
                        }
                    }
                    Text(label(step.kind)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(step.date.formatted(.dateTime.month(.abbreviated).day().year()) + (step.estimated ? " · est." : ""))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }

    private func icon(_ kind: String) -> String {
        switch kind {
        case "cinema": return "film"
        case "digital": return "play.tv"
        default: return "opticaldisc"
        }
    }

    private func label(_ kind: String) -> String {
        switch kind {
        case "cinema": return "Cinema"
        case "digital": return "Digital"
        default: return "Physical"
        }
    }
}

struct DetailRailStack: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.openURL) private var openURL
    let detail: ItemDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let key = detail.trailerKey, !key.isEmpty {
                DetailSection(title: "Trailer")
                Button {
                    if let url = URL(string: "https://www.youtube.com/watch?v=\(key)") { openURL(url) }
                } label: {
                    PosterImage(url: URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg"))
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .frame(width: 54, height: 54)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
                }
                .buttonStyle(DetailPressStyle())
                .accessibilityLabel("Play trailer")
            }

            if let collection = detail.collection, let name = collection.name {
                DetailSection(title: "Collection")
                Button {
                    withAnimation { store.tab = .collection }
                } label: {
                    HStack {
                        Image(systemName: "square.stack.3d.up").foregroundStyle(Theme.edition)
                        Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                    }
                    .padding(14)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
                }
                .buttonStyle(DetailPressStyle())
            }

            if let similar = detail.similar, !similar.isEmpty {
                DetailSection(title: "More like this")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(similar.indices, id: \.self) { i in
                            let title = similar[i]
                            VStack(alignment: .leading, spacing: 4) {
                                PosterImage(url: TMDBImage.resized(title.posterUrl, to: "w342"))
                                    .frame(width: 96, height: 144)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
                                Text(title.title ?? "")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.txt)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if let year = title.year {
                                        Text(verbatim: String(year)).font(.system(size: 11)).foregroundStyle(Theme.mut)
                                    }
                                    if title.inLibrary == true {
                                        Text("In library").font(.system(size: 9.5, weight: .bold)).foregroundStyle(Theme.done)
                                    }
                                }
                            }
                            .frame(width: 96)
                            .detailReveal(delay: Double(min(i, 8)) * 0.04, y: 8, duration: 0.4)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if let cast = detail.cast, !cast.isEmpty {
                DetailSection(title: "Cast")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(cast.indices, id: \.self) { i in
                            let person = cast[i]
                            VStack(spacing: 4) {
                                PosterImage(url: TMDBImage.resized(person.profileUrl, to: "h632"))
                                    .frame(width: 66, height: 66)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(Theme.line))
                                Text(person.name)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Theme.txt)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                if let character = person.character {
                                    Text(character)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Theme.mut)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(width: 80)
                            .detailReveal(delay: Double(min(i, 8)) * 0.04, y: 8, duration: 0.4)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// The movie Collection tab: the collection, with its full list in the web app.
struct CollectionTab: View {
    let detail: ItemDetail
    let openWeb: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(detail.collection?.name ?? "Collection")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.txt)
            Text("\(detail.title) is part of this collection. The full list of its movies, with what's in your library, is in the web app.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
            Button("Open in the web app", action: openWeb)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.cyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }
}
