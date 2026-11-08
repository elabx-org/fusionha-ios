import SwiftUI
import FusionhaKit

/// What a Replace (or Search for new copies, or Blocklist and search) asks about.
struct V2FixReplaceTarget: Identifiable {
    let items: [ManagedFileItem]
    let action: ManageFixAction
    /// The one file's episode title ("Replace Amari?").
    let name: String?
    let blocklistByDefault: Bool
    /// The files whose release may be blocklisted (damaged ones, or every
    /// file for Blocklist and search).
    let candidates: [ManagedFileItem]
    var id: [Int] { items.map(\.id) }
}

/// The Replace confirmation (mock frame 2): what happens in one sentence,
/// the release that would be blocklisted (`blocklist-target`), the
/// "Blocklist this release" toggle (on for damaged files, off for gone
/// ones; greyed with the reason as its subtitle when no file has a release
/// on record, and the Release card left out), then Cancel and the accent Replace. With the toggle on, files with
/// a release on record are deleted with it blocklisted and searched; the rest
/// go through the model's replace.
struct V2FixReplaceSheet: View {
    let model: ManageFilesModel
    let target: V2FixReplaceTarget
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pagePalette) private var page
    @State private var blocklist: Bool
    @State private var releases: [Int: FileBlocklistTarget] = [:]
    @State private var loaded = false
    @State private var running = false

    init(model: ManageFilesModel, target: V2FixReplaceTarget) {
        self.model = model
        self.target = target
        _blocklist = State(initialValue: target.blocklistByDefault)
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var canBlocklist: Bool { !releases.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(ManageFix.confirmTitle(target.action, count: target.items.count, name: target.name))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ink)
                Text(ManageFix.confirmMessage(target.items, isSeries: model.isSeries))
                    .font(.system(size: 14.5))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                if !target.candidates.isEmpty {
                    // No release on record: the switch stays, greyed, and says why itself.
                    if !loaded || canBlocklist { releaseCard }
                    toggle
                }
                buttons
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(running)
        .task { await loadReleases() }
    }

    @ViewBuilder private var releaseCard: some View {
        let shown = target.candidates.compactMap { releases[$0.id] }
        VStack(alignment: .leading, spacing: 4) {
            Text(shown.count > 1 ? "Releases" : "Release")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(muted)
            if !loaded {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(shown.prefix(3).enumerated()), id: \.offset) { _, r in
                    Text(r.releaseTitle)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if let t = r.transportLabel {
                        Text(t).font(.system(size: 12)).foregroundStyle(muted)
                    }
                }
                if shown.count > 3 {
                    Text("and \(shown.count - 3) more").font(.system(size: 12)).foregroundStyle(muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background { ModuleSurface(radius: 14) }
    }

    private var toggle: some View {
        Toggle(isOn: $blocklist) {
            VStack(alignment: .leading, spacing: 2) {
                Text(target.candidates.count > 1 ? "Blocklist these releases" : "Blocklist this release")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                Text(loaded && !canBlocklist
                     ? (target.candidates.count > 1 ? "Nothing to blocklist: fusionha didn’t grab these files"
                                                   : "Nothing to blocklist: fusionha didn’t grab this file")
                     : "So the same copy isn’t grabbed again")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
            }
        }
        .tint(Theme.primary)
        .disabled(running || !canBlocklist)
        .padding(14)
        .background { ModuleSurface(radius: 14) }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("Cancel").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .disabled(running)
            Button { Task { await run() } } label: {
                HStack(spacing: 8) {
                    if running { ProgressView().tint(Theme.onAccent) }
                    Text(ManageFix.confirmAction(target.action, count: target.items.count))
                }
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.primary)
            .disabled(running || (!loaded && !target.candidates.isEmpty))
        }
        .font(.system(size: 15.5, weight: .semibold))
    }

    private func loadReleases() async {
        guard let client = app.client, !loaded else { return }
        var found: [Int: FileBlocklistTarget] = [:]
        for item in target.candidates {
            if let r = try? await client.fileBlocklistTarget(fileId: item.id) { found[item.id] = r }
        }
        releases = found
        if found.isEmpty { blocklist = false }
        loaded = true
    }

    private func run() async {
        running = true
        let ids = blocklist ? Set(releases.keys) : []
        await model.fixReplace(target.items, blocklisting: ids)
        running = false
        dismiss()
    }
}
