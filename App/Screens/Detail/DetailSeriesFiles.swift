import SwiftUI
import UIKit
import FusionhaKit

// The series Files tab (FilesSections): one collapsible card per season ×
// version, one row per file.

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
            Text("Grouped by season, split by version — each tier lives in its own root folder, so its files are listed separately. Tap a section to collapse it.")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(Theme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Spacer()
                DetailRenameFilesButton { DetailWebOpener(model: model, openURL: openURL, itemId: detail.id)() }
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
                            DetailTierChip(tier: section.edition.tier, label: section.edition.label)
                            Spacer(minLength: 4)
                            Text("\(section.files.count) file\(section.files.count == 1 ? "" : "s") · \(DetailText.bytes(section.files.compactMap(\.size).reduce(0, +)))")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Theme.mut)
                                .lineLimit(1)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if !isCollapsed {
                        ForEach(section.files, id: \.id) { file in
                            Rectangle().fill(Theme.line).frame(height: 1)
                            DetailFileRow(file: file, tier: section.edition.tier)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .detailCard()
                .detailAnimation(.easeInOut(duration: 0.2), value: isCollapsed)
            }
        }
    }
}

struct DetailFileRow: View {
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
                    DetailTierChip(tier: tier, short: true)
                    DetailAnalysisBadge(file: file)
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
                .foregroundStyle(Theme.i2)
            }
            .padding(10)
            .background(Theme.bg.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))

            FlowRow(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.txt.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
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
                        .foregroundStyle(Theme.i2)
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
