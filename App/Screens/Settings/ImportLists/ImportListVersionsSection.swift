import SwiftUI
import FusionhaKit

/// "Versions to create" (web `VersionsField`): the HD and 4K rows, each on or
/// off with its own root folder and quality profile ("From Default Profiles"
/// until changed). Native pickers stand in for the web's Change selects.
struct ImportListVersionsSection: View {
    let store: ImportListsStore
    @Binding var draft: ImportListDraft

    var body: some View {
        Section {
            tierRows(.hd, $draft.hd)
            tierRows(.uhd, $draft.uhd)
        } header: {
            Text(ImportListCopy.versionsTitle)
        } footer: {
            Text(ImportListCopy.versionsHint)
        }
    }

    @ViewBuilder
    private func tierRows(_ tier: QualityTier, _ state: Binding<ImportListDraft.Tier>) -> some View {
        let name = tier == .hd ? "HD" : "4K"
        Toggle(isOn: state.on) {
            HStack(spacing: 10) {
                TierPill(tier: tier, large: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(name) version").foregroundStyle(Theme.txt)
                    Label(summary(state.wrappedValue), systemImage: "folder")
                        .font(.caption).foregroundStyle(Theme.mut).lineLimit(1)
                }
            }
        }
        .accessibilityLabel("\(name) version")
        if state.wrappedValue.on {
            Picker("\(name) root folder", selection: state.rootFolderId) {
                Text(ImportListCopy.fromDefaults).tag(Int?.none)
                ForEach(store.rootFolders) { Text($0.path).tag(Int?.some($0.id)) }
            }
            .pickerStyle(.menu)
            Picker("\(name) quality profile", selection: state.qualityProfileId) {
                Text(ImportListCopy.fromDefaults).tag(Int?.none)
                ForEach(store.profiles) { Text($0.name).tag(Int?.some($0.id)) }
            }
            .pickerStyle(.menu)
        }
    }

    /// "From Default Profiles", or "/movies-4k · UHD Remux".
    private func summary(_ t: ImportListDraft.Tier) -> String {
        guard t.custom else { return ImportListCopy.fromDefaults }
        let root = store.rootFolders.first { $0.id == t.rootFolderId }?.path ?? "Default root"
        let profile = store.profiles.first { $0.id == t.qualityProfileId }?.name ?? "Default profile"
        return "\(root) · \(profile)"
    }
}

/// What a save would do (web `PreviewCard`): the counts, the movie / series
/// mix and a sample of posters. Nothing is written.
struct ImportListPreviewSection: View {
    let preview: ImportListPreview

    var body: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { facts }
                VStack(alignment: .leading, spacing: 3) { facts }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.mut)
            if preview.mix.total > 0 { MixBar(mix: preview.mix) }
            PosterStrip(items: preview.items.prefix(8).map { PosterStrip.Item($0) })
        } footer: {
            Text("A sample of \(preview.items.count). Nothing is added until you save.")
        }
    }

    @ViewBuilder private var facts: some View {
        fact(preview.itemCount ?? preview.mix.total, "titles")
        Text("\(bold(preview.mix.movies)) movies · \(bold(preview.mix.series)) series")
        Text("\(bold(preview.inLibraryCount)) already in the library").foregroundStyle(Theme.text(.done))
        fact(preview.excludedCount, "excluded")
        fact(preview.wouldAdd, "would be added")
    }

    private func fact(_ n: Int, _ word: String) -> Text { Text("\(bold(n)) \(word)") }
    private func bold(_ n: Int) -> Text { Text("\(n)").bold().foregroundStyle(Theme.txt) }
}
