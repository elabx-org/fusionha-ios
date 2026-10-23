import SwiftUI
import FusionhaKit

/// The detail's Options (web `SourceOptions`, `LetterboxdOptions`,
/// `PlexOptions`): the source's own switches and its "What was on it when you
/// started", per kind. Each saves on its own.
struct SourceOptionsSection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let view: AutoSourceView
    let data: AutoSourceDetail

    private var diary: LetterboxdDiary? { store.letterboxd?.diary }
    private var lbLocked: Bool { store.letterboxd.map { !$0.alsoUhdAllowed } ?? false }
    private var plexLocked: Bool { view.plex.map { !$0.alsoUhdAllowed } ?? false }

    var body: some View {
        Section(SourceDetailCopy.options) {
            switch view.kind {
            case .diary: diaryRows
            case .ownWatchlist: ownWatchlistRows
            case .list, .watchlist: linkedRows
            case .plexWatchlist: plexWatchlistRows
            case .plexList:
                toggle(SourceDetailCopy.plexList, on: data.enabled) { await store.setEnabled(view, $0, model) }
                baseline(diary: false)
            }
        }
        .listRowBackground(AccountStyle.cell)
    }

    @ViewBuilder
    private var diaryRows: some View {
        let user = store.letterboxd?.username != nil
        toggle(SourceDetailCopy.diarySwitch, desc: SourceDetailCopy.diaryDesc, on: diary?.enabled ?? data.enabled,
               disabled: !user) { await store.setEnabled(view, $0, model) }
        baseline(diary: true)
        toggle(SourceDetailCopy.rewatches, desc: SourceDetailCopy.rewatchesDesc, on: diary?.requestRewatches ?? false,
               disabled: !user) { await store.setRewatch(view, $0, model) }
        toggle(SourceDetailCopy.uhd, desc: lbLocked ? SourceDetailCopy.uhdOff : nil,
               on: (diary?.alsoUhd ?? data.uhd) && !lbLocked, disabled: !user || lbLocked) {
            await store.setUhd(view, $0, model)
        }
    }

    @ViewBuilder
    private var ownWatchlistRows: some View {
        let follow = store.letterboxd?.watchlistFollow
        toggle(SourceDetailCopy.followWatchlist, desc: SourceDetailCopy.followWatchlistDesc,
               on: follow?.enabled ?? data.enabled) { await store.setEnabled(view, $0, model) }
        baseline(diary: false)
        // Its own value; until set it uses the diary's (the read gives the effective one).
        toggle(SourceDetailCopy.uhd, desc: lbLocked ? SourceDetailCopy.uhdOff : SourceDetailCopy.uhdDesc,
               on: (follow?.alsoUhd ?? data.uhd) && !lbLocked, disabled: view.rowId == nil || lbLocked) {
            await store.setUhd(view, $0, model)
        }
    }

    @ViewBuilder
    private var linkedRows: some View {
        baseline(diary: false)
        toggle(SourceDetailCopy.autoList, on: data.enabled, disabled: view.rowId == nil) {
            await store.setEnabled(view, $0, model)
        }
        Text(SourceDetailCopy.uhdInherits).font(.footnote).foregroundStyle(Theme.mut)
    }

    @ViewBuilder
    private var plexWatchlistRows: some View {
        toggle(SourceDetailCopy.plexWatchlist, on: data.enabled) { await store.setEnabled(view, $0, model) }
        baseline(diary: false)
        toggle(SourceDetailCopy.uhd, desc: plexLocked ? SourceDetailCopy.uhdOff : nil,
               on: data.uhd && !plexLocked, disabled: plexLocked) { await store.setUhd(view, $0, model) }
    }

    private func baseline(diary: Bool) -> some View {
        BaselinePicker(value: data.baseline, diary: diary, noted: data.counts.baseline, disabled: store.acting) {
            await store.setBaseline(view, $0, model)
        }
    }

    private func toggle(_ title: String, desc: String? = nil, on: Bool, disabled: Bool = false,
                        save: @escaping (Bool) async -> Bool) -> some View {
        OptionToggle(title: title, desc: desc, value: on, save: save)
            .disabled(disabled)
    }
}

/// A switch that shows the new value while it saves and goes back if the save fails.
struct OptionToggle: View {
    let title: String
    var desc: String?
    let value: Bool
    let save: (Bool) async -> Bool
    @State private var shown: Bool?
    @State private var saving = false

    var body: some View {
        Toggle(isOn: Binding(get: { shown ?? value }, set: { flip($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Theme.txt)
                if let desc { Text(desc).font(.caption).foregroundStyle(Theme.mut) }
            }
        }
        .disabled(saving)
        .onChange(of: value) { shown = nil }
    }

    private func flip(_ on: Bool) {
        shown = on
        saving = true
        Task {
            // Saved or not, the re-read value is the truth from here on.
            _ = await save(on)
            saving = false
            shown = nil
        }
    }
}
