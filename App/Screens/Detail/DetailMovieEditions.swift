import SwiftUI
import UIKit
import FusionhaKit

// The movie Versions tab (MovieEditionsTable, mobile cards): one card per
// version, owned or wanted.

// MARK: - Movie Editions tab

struct MovieEditionsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    @State private var searchingAll = false

    var body: some View {
        let editions = store.scopedEditions
        let owned = editions.filter { $0.movieFile != nil }
        let bytes = owned.compactMap { $0.movieFile?.size }.reduce(0, +)
        // `wanted` = versions with no file (MovieVersionsTable).
        let wanted = editions.count - owned.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: -4) {
                    ForEach(editions) { e in
                        DetailDot(color: e.movieFile != nil ? DetailTokens.tier(e.tier) : Theme.miss, size: 11, mono: e.movieFile != nil ? e.tier.monoToken : .miss)
                    }
                }
                let countText = Text("\(owned.count) of \(editions.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Theme.txt)
                let bytesText = Text(DetailText.bytes(bytes))
                    .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Theme.txt)
                let tail: String = wanted == 0 ? " · all at cutoff" : " · \(wanted) wanted"
                (countText + Text(" versions · ") + bytesText + Text(tail))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if (model.me?.can("edit") ?? true) && !owned.isEmpty { DetailRenameFilesButton { store.openRename() } }
                    if model.me?.can("search") ?? true {
                        Button {
                            searchingAll = true
                            Task {
                                await store.search(label: "all monitored versions")
                                searchingAll = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if searchingAll { DetailSpinner(size: 13, color: Theme.onAccent) } else { Image(systemName: "magnifyingglass") }
                                Text("Search all monitored")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Theme.primary, in: Capsule())
                        }
                        .buttonStyle(DetailPressStyle())
                        .disabled(searchingAll)
                    }
                }
            }
            .scrollIndicators(.hidden)
            ForEach(editions) { edition in
                if edition.movieFile != nil {
                    DetailOwnedEditionCard(detail: detail, edition: edition)
                } else {
                    DetailWantedEditionCard(detail: detail, edition: edition)
                }
            }
        }
    }
}

struct DetailStatusIconBox: View {
    let dot: EditionDot
    var body: some View {
        let color = DetailTokens.dot(dot)
        Group {
            switch dot {
            case .done: Image(systemName: "checkmark.circle")
            case .grab: Image(systemName: "arrow.down").detailPulse()
            case .upgrade: Image(systemName: "arrow.up")
            case .miss: Image(systemName: "exclamationmark.circle")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 26, height: 26)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct DetailMonitorBookmark: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let edition: DetailEdition

    var body: some View {
        let on = store.editionMonitored(edition)
        Button {
            Task { await store.setEditionMonitored(edition, !on) }
        } label: {
            Image(systemName: on ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(on ? Theme.txt : Theme.dim)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, -9).padding(.vertical, -9)
        }
        .buttonStyle(DetailPressStyle())
        .disabled(!(model.me?.can("edit") ?? true))
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(on ? "Monitored. Tap to stop monitoring \(edition.label)" : "Not monitored. Tap to monitor \(edition.label)")
    }
}
