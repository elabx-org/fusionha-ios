import SwiftUI
import UIKit
import FusionhaKit

/// One episode file (mock kit `fileCard`, browse-title.js `movieFileCard`):
/// the quality large with the release's name, the score, the facts in a
/// grid (v1's `EpisodeFileFacts`: the server's probe first, the filename
/// where it has none), the custom formats and the full path. A dead link
/// says so in orange. Copy path and Delete file sit under the history
/// (`V2EpisodeFileActions`, the mock's footer row).
struct V2EpisodeFileCard: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let version: DetailEdition
    let file: MovieFile
    let monitored: Bool
    @State private var width: CGFloat = 0

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var path: String { V2EpisodeFilePath.full(file, version: version, store: store) }

    var body: some View {
        let facts = EpisodeFileFacts(file: file, tier: version.tier)
        VStack(alignment: .leading, spacing: 12) {
            header(facts)
            if let note = facts.belowTierNote(version.tier) {
                Label(note, systemImage: "arrow.up.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(muted)
            }
            if facts.deadLink {
                Label(facts.onDisk(file), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.stuck)
            }
            grid(facts)
            if let formats = file.customFormats, !formats.isEmpty {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    ForEach(formats, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(muted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            Text(path)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(muted)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 22) }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func header(_ facts: EpisodeFileFacts) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    EditionBadge(tier: version.tier, state: file.unresolved == true ? .held : .onDisk)
                    Text(facts.quality ?? file.quality ?? version.label)
                        .font(.system(size: 20, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(file.sceneName ?? ((file.relativePath ?? "") as NSString).lastPathComponent)
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if let score = file.cfScore {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(DetailText.score(score))
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(score < 0 ? Theme.danger : ink)
                    Text("score").font(.system(size: 11)).foregroundStyle(muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Custom format score \(DetailText.score(score))")
            }
        }
    }

    private func grid(_ facts: EpisodeFileFacts) -> some View {
        let cells: [(String, String?)] = [
            ("Size", facts.sizeAndLength), ("Group", facts.group), ("Resolution", facts.resolution),
            ("Video", facts.video), ("Audio", facts.audio), ("Languages", facts.languages),
            ("Linked as", facts.deadLink ? nil : facts.onDisk(file)),
        ]
        let shown: [(String, String)] = cells.compactMap { cell -> (String, String)? in
            guard let value = cell.1, !value.isEmpty else { return nil }
            return (cell.0, value)
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading), count: width < 330 ? 2 : 3)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(shown.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 1) {
                    Text(shown[i].0).font(.system(size: 11, weight: .semibold)).tracking(0.22).foregroundStyle(muted)
                    Text(shown[i].1).font(.system(size: 14, weight: .bold)).foregroundStyle(ink).lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Copy path and Delete file for the shown file, under the history strip
/// (mock `episodePhone` footer: two h40 pills outside the card).
struct V2EpisodeFileActions: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let version: DetailEdition
    let file: MovieFile
    @State private var confirmDelete = false

    var body: some View {
        HStack(spacing: 8) {
            Button("Copy path", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = V2EpisodeFilePath.full(file, version: version, store: store)
                store.show("Path copied", variant: .success)
            }
            .foregroundStyle(page?.ink ?? Theme.txt)
            if model.me?.can("delete_files") ?? true {
                Button("Delete file", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .foregroundStyle(Theme.danger)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 14, weight: .semibold))
        .buttonStyle(.glass)
        .frame(minHeight: 40)
        .confirmationDialog("Delete this file?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: false) } }
            Button("Delete and blocklist", role: .destructive) { Task { await store.deleteFile(file.id, blocklist: true) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(((file.relativePath ?? "") as NSString).lastPathComponent)
        }
    }
}
