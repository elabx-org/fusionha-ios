import SwiftUI
import FusionhaKit

/// The episode checklist (the web's `EpisodeSheet`). A file can cover several
/// episodes: every toggle sends the whole set as episode numbers in the row's
/// season, and the release type follows. The last ticked episode stays.
struct MIEpisodeSheet: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// The row as it is now (it changes under the sheet as each toggle lands).
    private var live: ManualImportRow { session.rows.first { $0.rowId == row.rowId } ?? row }
    private var seasons: [Season] { row.match.itemId.flatMap { session.seasons[$0] } ?? [] }

    var body: some View {
        let current = live
        let season = current.target.season
        let selected = Set(current.target.coveredEpisodeIds)
        let episodes = seasons.first { $0.seasonNumber == season }?.episodes.sorted { $0.episodeNumber < $1.episodeNumber } ?? []
        NavigationStack {
            List {
                Section {
                    Picker("Season", selection: Binding(get: { season ?? -1 }, set: { pickSeason($0) })) {
                        if season == nil { Text("—").tag(-1) }
                        ForEach(seasons.map(\.seasonNumber).sorted(), id: \.self) { Text("Season \($0)").tag($0) }
                    }
                }
                Section("Episodes") {
                    if episodes.isEmpty {
                        Text(seasons.isEmpty ? "Loading episodes…" : "No episodes in this season.").foregroundStyle(Theme.mut)
                    }
                    ForEach(episodes) { ep in
                        let on = selected.contains(ep.id)
                        Button { toggle(ep, selected: selected, in: episodes) } label: {
                            HStack {
                                Text("\(EpisodeCode.num(ep.episodeNumber)) · \(ep.title ?? "Episode \(ep.episodeNumber)")")
                                    .foregroundStyle(Theme.txt)
                                Spacer()
                                if on { Image(systemName: "checkmark").foregroundStyle(Theme.i1) }
                            }
                        }
                        .disabled(on && selected.count == 1)
                    }
                }
            }
            .navigationTitle("Episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } } }
            .closeOnlyBars()
            .disabled(session.pendingRows.contains(row.rowId))
            .task { if let item = row.match.itemId { await session.loadSeasons(itemId: item) } }
        }
        .presentationDetents([.medium, .large])
    }

    private func pickSeason(_ n: Int) {
        guard n >= 0, n != live.target.season else { return }
        Task { await session.patch(live, ["season": .int(n), "episode": nil]) }
    }

    private func toggle(_ ep: Episode, selected: Set<Int>, in episodes: [Episode]) {
        var next = selected
        if next.contains(ep.id) { next.remove(ep.id) } else { next.insert(ep.id) }
        let numbers = episodes.filter { next.contains($0.id) }.map(\.episodeNumber).sorted()
        guard !numbers.isEmpty else { return }
        Task { await session.patch(live, ["episodes": .ints(numbers)]) }
    }
}

/// The per-row language override (multi-select).
struct MILanguagesSheet: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var picked: [String] = []

    var body: some View {
        NavigationStack {
            List(ManualImportRules.languages, id: \.self) { lang in
                Button {
                    if let i = picked.firstIndex(of: lang) { picked.remove(at: i) } else { picked.append(lang) }
                } label: {
                    HStack {
                        Text(lang).foregroundStyle(Theme.txt)
                        Spacer()
                        if picked.contains(lang) { Image(systemName: "checkmark").foregroundStyle(Theme.i1) }
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton {
                        let langs = picked
                        if langs != (row.languages ?? []) {
                            Task { await session.patch(row, ["languages": .array(langs.map(SettingsJSON.string))]) }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { picked = row.languages ?? [] }
        }
        .presentationDetents([.medium, .large])
    }
}
