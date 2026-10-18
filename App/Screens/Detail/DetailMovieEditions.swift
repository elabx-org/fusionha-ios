import SwiftUI
import UIKit
import FusionhaKit

// The movie Versions tab (MovieEditionsTable, mobile cards): one card per
// version, owned or wanted.

// MARK: - Movie Editions tab

struct MovieEditionsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
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
                        DetailDot(color: e.movieFile != nil ? (e.tier == .hd ? Theme.edition : Theme.grab) : Theme.miss, size: 11)
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
                    DetailRenameFilesButton { DetailWebOpener(model: model, openURL: openURL, itemId: detail.id)() }
                    if model.me?.can("search") ?? true {
                        Button {
                            searchingAll = true
                            Task {
                                await store.search(label: "all monitored versions")
                                searchingAll = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if searchingAll { DetailSpinner(size: 13, color: Theme.onPrimary) } else { Image(systemName: "magnifyingglass") }
                                Text("Search all monitored")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Theme.fusion, in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1)
                                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
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

struct DetailOwnedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var confirmDelete = false

    var body: some View {
        let file = edition.movieFile
        let probe = file?.mediaInfo?.probe
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                DetailStatusIconBox(dot: store.dot(edition))
                TierPill(tier: edition.tier, large: true).fixedSize()
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                if let file { DetailAnalysisBadge(file: file) }
                Spacer(minLength: 0)
                DetailMonitorBookmark(edition: edition)
            }
            Text(file?.relativePath ?? "")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 10, lineSpacing: 6) {
                DetailQualityChip(quality: file?.quality, tier: edition.tier)
                if let v = DetailMediaFacts.codec(probe) { Text(v) }
                Text(DetailMediaFacts.audio(probe) ?? "—")
                if let v = DetailMediaFacts.range(probe) { Text(v) }
                Text(DetailText.bytes(file?.size))
                if let g = file?.releaseGroup, !g.isEmpty { Text(g) }
                Button {
                    UIPasteboard.general.string = file?.relativePath
                    store.show("Path copied", variant: .success)
                } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy path")
            }
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(Theme.mut)
            HStack(spacing: 8) {
                if model.me?.can("search") ?? true {
                    SearchActionButton(label: edition.label, editionId: edition.id, size: 40, glyph: 15, bordered: true)
                    DetailSquareAction(systemImage: "person", label: "Interactive search", size: 40) {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                }
                if let file, file.linkUnresolved == true, model.me?.can("manage_files") ?? true {
                    Button("Clean up") { Task { await store.cleanupLink(file.id) } }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.i2)
                        .buttonStyle(.plain)
                }
                if model.me?.can("delete_files") ?? true {
                    DetailSquareAction(systemImage: "trash", label: "Delete file", size: 40) { confirmDelete = true }
                }
            }
        }
        .padding(16)
        .detailCard()
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            if let id = file?.id {
                Button("Delete", role: .destructive) { Task { await store.deleteFile(id, blocklist: false) } }
                Button("Delete & blocklist", role: .destructive) { Task { await store.deleteFile(id, blocklist: true) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct DetailWantedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var searching = false

    var body: some View {
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DetailStatusIconBox(dot: store.dot(edition))
                TierPill(tier: edition.tier, large: true).fixedSize()
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                Spacer(minLength: 0)
                DetailMonitorBookmark(edition: edition)
            }
            if edition.downloadState == "downloading", let release = edition.releaseTitle {
                HStack(spacing: 6) {
                    DetailSpinner(size: 11, color: Theme.grab, period: 0.9)
                    Text(release).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.grab).lineLimit(1)
                }
            }
            (Text("Target profile ") + Text(store.profileName(edition.qualityProfileId)).fontWeight(.bold).foregroundColor(Theme.txt)
                + Text(" · cutoff \(cutoff)"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
            HStack(spacing: 8) {
                if model.me?.can("search") ?? true {
                    Button {
                        searching = true
                        Task {
                            await store.search(label: edition.label, editionId: edition.id)
                            searching = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if searching { DetailSpinner(size: 12, color: Theme.done) } else { Image(systemName: "magnifyingglass") }
                            Text("Search")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(DetailPressStyle())
                    .glassControl()
                    .disabled(searching)
                    DetailSquareAction(systemImage: "person", label: "Interactive search", size: 40) {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                }
                if model.me?.can("edit") ?? true {
                    DetailSquareAction(systemImage: "pencil", label: "Edit version", size: 40) { store.showingEdit = true }
                }
            }
        }
        .padding(16)
        .detailCard()
    }
}
