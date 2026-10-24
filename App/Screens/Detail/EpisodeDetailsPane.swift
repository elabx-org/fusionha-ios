import SwiftUI
import UIKit
import FusionhaKit

/// The episode sheet's Details tab: the overview, Monitored / Runtime and one
/// status per scoped version, then a block per owned file (path + Copy, the
/// media chips, Replace or Clean up on a dead link, Delete file).
struct EpisodeDetailsPane: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    var body: some View {
        let versions = store.scopedEditions
        VStack(alignment: .leading, spacing: 16) {
            Text(episode.overview?.isEmpty == false ? episode.overview! : "No episode description.")
                .font(.system(size: 14))
                .foregroundStyle(episode.overview?.isEmpty == false ? Theme.txt : Theme.dim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .readableWidth()
            VStack(spacing: 0) {
                row("Monitored") { Text(store.episodeMonitored(episode) ? "Yes" : "No") }
                row("Runtime") { Text(episode.runtime.map { "\($0) min" } ?? "—") }
                ForEach(versions) { version in
                    row(version.label) { EpisodeStatusChip(episode: episode, edition: version) }
                }
            }
            .detailCard(radius: 14, shadow: false)
            ForEach(versions) { version in
                if let file = episode.file(for: version.id) {
                    EpisodeFileBlock(version: version, file: file,
                                     monitored: store.editionMonitored(version) && store.episodeMonitored(episode))
                }
            }
        }
    }

    private func row<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.mut)
            Spacer(minLength: 8)
            value().font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 14) }
    }
}

/// One owned file of the episode.
private struct EpisodeFileBlock: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let version: DetailEdition
    let file: MovieFile
    let monitored: Bool
    @State private var confirm: Confirm?

    private enum Confirm { case delete, replace, cleanup }

    private var fullPath: String {
        let root = store.rootPath(version)
        guard let rel = file.relativePath else { return root }
        return root == "—" ? rel : (root as NSString).appendingPathComponent(rel)
    }

    private var chips: [String] {
        var out: [String] = [DetailText.quality(file.quality)]
        let probe = file.mediaInfo?.probe
        if let v = DetailMediaFacts.codec(probe) { out.append(v) }
        if let v = DetailMediaFacts.audio(probe) { out.append(v) }
        if let v = DetailMediaFacts.range(probe) { out.append(v) }
        if let v = file.releaseGroup, !v.isEmpty { out.append(v) }
        out.append(DetailText.bytes(file.size))
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DetailTierChip(tier: version.tier, label: version.label)
                if file.unresolved == true {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Theme.stuck)
                        .accessibilityLabel("File needs attention")
                }
                DetailAnalysisBadge(file: file)
                Spacer(minLength: 0)
                if let score = file.cfScore {
                    Text(score >= 0 ? "+\(score)" : "\(score)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(score < 0 ? Theme.danger : Theme.mut)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Text(fullPath)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = fullPath }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy path")
            }
            .padding(10)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            FlowRow(spacing: 6, lineSpacing: 6) {
                ForEach(chips.indices, id: \.self) { i in
                    Text(chips[i])
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.txt.opacity(0.06), in: Capsule())
                }
            }
            if model.me?.can("edit") ?? true { actions }
        }
        .padding(14)
        .detailCard(radius: 14, shadow: false)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if let confirm {
                Text(confirmText(confirm)).font(.system(size: 12)).foregroundStyle(Theme.txt)
                Spacer(minLength: 4)
                Button("Cancel") { self.confirm = nil }.buttonStyle(.glass)
                Button(confirmLabel(confirm), role: .destructive) { run(confirm) }
                    .buttonStyle(.glassProminent).tint(Theme.danger)
            } else {
                Spacer(minLength: 0)
                if file.linkUnresolved == true {
                    Button(monitored ? "Replace" : "Clean up",
                           systemImage: monitored ? "arrow.triangle.2.circlepath" : "link.badge.plus") {
                        confirm = monitored ? .replace : .cleanup
                    }
                    .buttonStyle(.glass)
                }
                Button("Delete file", systemImage: "trash", role: .destructive) { confirm = .delete }
                    .buttonStyle(.glass)
                    .tint(Theme.danger)
            }
        }
        .font(.system(size: 12.5, weight: .semibold))
        .controlSize(.small)
    }

    private func confirmText(_ c: Confirm) -> String {
        switch c {
        case .delete: return "Delete this file?"
        case .replace: return "Replace this file? (delete + re-grab)"
        case .cleanup: return "Clean up this file? (delete)"
        }
    }

    private func confirmLabel(_ c: Confirm) -> String {
        switch c {
        case .delete: return "Delete"
        case .replace: return "Replace"
        case .cleanup: return "Clean up"
        }
    }

    private func run(_ c: Confirm) {
        confirm = nil
        Task {
            switch c {
            case .delete: await store.deleteFile(file.id, blocklist: false)
            case .replace: await store.replaceFile(file.id)
            case .cleanup: await store.cleanupLink(file.id)
            }
        }
    }
}
