import SwiftUI
import UIKit
import FusionhaKit

// The series Files tab (FilesSections) and the movie Editions tab
// (MovieEditionsTable, mobile cards).

/// Opens this item in the web app (for the dialogs that live there).
@MainActor
private struct WebOpener {
    let model: AppModel
    let openURL: OpenURLAction
    let itemId: Int

    func callAsFunction() {
        guard let server = model.credentials?.serverURL else { return }
        openURL(server.appendingPathComponent("library/\(itemId)"))
    }
}

private struct RenameFilesButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Rename files", systemImage: "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
        }
        .buttonStyle(DetailPressStyle())
    }
}

// MARK: - Series files

struct SeriesFilesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let detail: ItemDetail
    @State private var collapsed: Set<String> = []

    private struct FileSection: Identifiable {
        let season: Season
        let edition: DetailEdition
        let files: [MovieFile]
        var id: String { "\(season.seasonNumber)-\(edition.id)" }
    }

    private var sections: [FileSection] {
        let seasons = (detail.seasons ?? []).sorted { $0.seasonNumber < $1.seasonNumber }
        var out: [FileSection] = []
        for season in seasons {
            for edition in store.scopedEditions {
                var seen = Set<Int>()
                var files: [MovieFile] = []
                for ep in season.episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
                    if let f = ep.file(for: edition.id), !seen.contains(f.id) {
                        seen.insert(f.id)
                        files.append(f)
                    }
                }
                if !files.isEmpty { out.append(FileSection(season: season, edition: edition, files: files)) }
            }
        }
        return out
    }

    var body: some View {
        let sections = sections
        VStack(alignment: .leading, spacing: 12) {
            Text("Grouped by season, split by edition — each tier lives in its own root folder, so its files are listed separately. Tap a section to collapse it.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(Theme.dim)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
            HStack {
                Spacer()
                RenameFilesButton { WebOpener(model: model, openURL: openURL, itemId: detail.id)() }
            }
            if sections.isEmpty {
                EmptyBox(message: "No files imported yet.")
            }
            ForEach(sections) { section in
                let isCollapsed = collapsed.contains(section.id)
                VStack(spacing: 0) {
                    Button {
                        if isCollapsed { collapsed.remove(section.id) } else { collapsed.insert(section.id) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                                .foregroundStyle(Theme.mut)
                            Image(systemName: "folder").foregroundStyle(Theme.mut)
                            Text(section.season.title).foregroundStyle(Theme.txt)
                            TierChip(tier: section.edition.tier, label: section.edition.label)
                            Spacer(minLength: 4)
                            Text("\(section.files.count) file\(section.files.count == 1 ? "" : "s") · \(DetailText.bytes(section.files.compactMap(\.size).reduce(0, +)))")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Theme.mut)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(Theme.panel2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if !isCollapsed {
                        ForEach(section.files, id: \.id) { file in
                            Rectangle().fill(Theme.line).frame(height: 1)
                            FileRow(file: file, tier: section.edition.tier)
                        }
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line))
                .detailAnimation(.easeInOut(duration: 0.2), value: isCollapsed)
            }
        }
    }
}

/// The edition chip in a section header. HD is purple, 4K cyan (not the web's green HD).
private struct TierChip: View {
    let tier: QualityTier
    var label: String? = nil
    var short = false

    var body: some View {
        let color = DetailTokens.tier(tier)
        Text(short ? tier.tierShort : (label ?? tier.chipLabel))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The spinner shown while a file's media analysis is pending (MediaInfoBadge).
private struct AnalysisBadge: View {
    let file: MovieFile
    var body: some View {
        if file.analysis == "pending" {
            DetailSpinner(size: 13, color: Theme.indigo, period: 0.9)
                .accessibilityLabel("Analysing")
        } else if file.analysis == "failed" {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(Theme.miss)
                .accessibilityLabel("Analysis failed")
        }
    }
}

private struct FileRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let file: MovieFile
    let tier: QualityTier
    @State private var expanded = false
    @State private var confirmDelete = false

    private var basename: String { ((file.relativePath ?? "") as NSString).lastPathComponent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Text(basename)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TierChip(tier: tier, short: true)
                    AnalysisBadge(file: file)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                expandedBody
                    .padding(.horizontal, 15)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .detailAnimation(.easeInOut(duration: 0.2), value: expanded)
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: false) } }
            Button("Delete & blocklist", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(basename)
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(file.relativePath ?? "")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = file.relativePath
                    store.show("Path copied", variant: .success)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc").font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.cyan)
            }
            .padding(10)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))

            FlowRow(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                }
            }

            HStack(spacing: 10) {
                Text(file.linkUnresolved == true ? "Dead link · target gone from disk" : "Imported")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(file.linkUnresolved == true ? Theme.stuck : Theme.done)
                Spacer(minLength: 0)
                if file.linkUnresolved == true, model.me?.can("manage_files") ?? true {
                    Button("Clean up dead link") { Task { await store.cleanupLink(file.id) } }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.cyan)
                        .buttonStyle(.plain)
                }
                if model.me?.can("delete_files") ?? true {
                    DetailSquareAction(systemImage: "trash", label: "Delete file", size: 36, tint: Theme.danger) { confirmDelete = true }
                }
            }
        }
    }

    private var chips: [String] {
        var out: [String] = []
        if let q = file.quality { out.append(q) }
        let probe = file.mediaInfo?.probe
        if let v = DetailMediaFacts.codec(probe) { out.append(v) }
        if let v = DetailMediaFacts.audio(probe) { out.append(v) }
        if let v = DetailMediaFacts.range(probe), v != "SDR" { out.append(v) }
        if let g = file.releaseGroup, !g.isEmpty { out.append(g) }
        if let mode = file.mediaInfo?.finalMode { out.append(mode.lowercased()) }
        out.append(DetailText.bytes(file.size))
        return out
    }
}

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
        let wanted = editions.filter { e in
            guard let file = e.movieFile else { return true }
            return !DetailText.meetsCutoff(file.quality, cutoff: store.cutoff(e.qualityProfileId))
        }.count
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
                (countText + Text(" editions · ") + bytesText + Text(tail))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    RenameFilesButton { WebOpener(model: model, openURL: openURL, itemId: detail.id)() }
                    if model.me?.can("search") ?? true {
                        Button {
                            searchingAll = true
                            Task {
                                await store.search(label: "all editions")
                                searchingAll = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if searchingAll { DetailSpinner(size: 13, color: .white) } else { Image(systemName: "magnifyingglass") }
                                Text("Search all monitored")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(DetailPressStyle())
                        .disabled(searchingAll)
                    }
                }
            }
            .scrollIndicators(.hidden)
            ForEach(editions) { edition in
                if edition.movieFile != nil {
                    OwnedEditionCard(detail: detail, edition: edition)
                } else {
                    WantedEditionCard(detail: detail, edition: edition)
                }
            }
        }
    }
}

private struct StatusIconBox: View {
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

private struct MonitorBookmark: View {
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
                .foregroundStyle(on ? Theme.cyan : Theme.dim)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(DetailPressStyle())
        .disabled(!(model.me?.can("edit") ?? true))
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel(on ? "Monitored — tap to stop monitoring \(edition.label)" : "Not monitored — tap to monitor \(edition.label)")
    }
}

private struct OwnedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var confirmDelete = false

    var body: some View {
        let file = edition.movieFile
        let probe = file?.mediaInfo?.probe
        let tierColor = edition.tier == .hd ? Theme.edition : Theme.grab
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                StatusIconBox(dot: store.dot(edition))
                HStack(spacing: 6) {
                    DetailDot(color: tierColor)
                    Text(edition.tier.chipLabel).font(.system(size: 13, weight: .heavy)).foregroundStyle(tierColor)
                }
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                if let file { AnalysisBadge(file: file) }
                Spacer(minLength: 0)
                MonitorBookmark(edition: edition)
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
                        .foregroundStyle(Theme.cyan)
                        .buttonStyle(.plain)
                }
                if model.me?.can("delete_files") ?? true {
                    DetailSquareAction(systemImage: "trash", label: "Delete file", size: 40) { confirmDelete = true }
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            if let id = file?.id {
                Button("Delete", role: .destructive) { Task { await store.deleteFile(id, blocklist: false) } }
                Button("Delete & blocklist", role: .destructive) { Task { await store.deleteFile(id, blocklist: true) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct WantedEditionCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let edition: DetailEdition
    @State private var searching = false

    var body: some View {
        let tierColor = edition.tier == .hd ? Theme.edition : Theme.grab
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StatusIconBox(dot: store.dot(edition))
                HStack(spacing: 6) {
                    DetailDot(color: tierColor)
                    Text(edition.tier.chipLabel).font(.system(size: 13, weight: .heavy)).foregroundStyle(tierColor)
                }
                if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                Spacer(minLength: 0)
                MonitorBookmark(edition: edition)
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.done)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Theme.grab.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(DetailPressStyle())
                    .disabled(searching)
                    DetailSquareAction(systemImage: "person", label: "Interactive search", size: 40) {
                        store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
                    }
                }
                if model.me?.can("edit") ?? true {
                    DetailSquareAction(systemImage: "pencil", label: "Edit edition", size: 40) { store.showingEdit = true }
                }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }
}
