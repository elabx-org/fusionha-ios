import SwiftUI
import FusionhaKit

// MARK: - Wanted card

struct WantedCardView: View {
    let item: WantedItem
    let tab: WantedTab
    let interval: Int
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var searchingKey: String?
    @State private var gradualRun: Int?
    @State private var gradualTotal = 0

    var body: some View {
        if let head = WantedLogic.primaryEdition(item, tab) {
            card(head)
        }
    }

    private func card(_ head: WantedEdition) -> some View {
        let kind = WantedLogic.kind(isAnime: item.isAnime, kind: item.kind)
        let tone = WantedLogic.stateTone(head.state == "missing" || head.state == "cutoff_unmet" || head.state == "upcoming" ? head.state : "missing")
        let nested = tab == .missing && item.kind == .series ? (head.missingEpisodes ?? []) : []
        let total = head.missingEpisodeCount ?? nested.count
        let extra = total - nested.count
        return ActGroupCard(wash: tone, base: Theme.panel, defaultOpen: true, hasTrailing: false) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
        } title: {
            VStack(alignment: .leading, spacing: 5) {
                ActFlow(spacing: 9, lineSpacing: 4) {
                    Text(item.title).font(.system(size: 15, weight: .bold)).tracking(-0.15).foregroundStyle(Theme.txt)
                    WantedKindPill(kind: kind)
                    HStack(spacing: 4) {
                        StatusGlyph(token: WantedStateToken.token(head.state), size: 10)
                        Text(WantedLogic.stateLabel(head.state)).font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundStyle(WantedLogic.stateColor(head.state))
                }
                ActFlow(spacing: 8, lineSpacing: 4) {
                    ForEach(item.editions) { edition in editionChip(edition) }
                    Text("· \(WantedLogic.cue(item, head))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }
        } trailing: {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                detailRow
                if let gradualRun {
                    WantedGradualStrip(itemId: item.id, runId: gradualRun, fallbackTotal: gradualTotal, interval: interval) {
                        withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { self.gradualRun = nil }
                    }
                    .transition(.opacity)
                }
                if !nested.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(nested.enumerated()), id: \.element.id) { index, ep in
                            if index > 0 { WantedDashedLine().padding(.horizontal, 0) }
                            episodeRow(ep)
                        }
                        if extra > 0 {
                            WantedDashedLine()
                            Text("+\(extra) more aired episode\(extra == 1 ? "" : "s") not shown")
                                .font(.system(size: 11.5))
                                .italic()
                                .foregroundStyle(Theme.dim)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                        }
                    }
                    .background(Theme.panel2)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
        }
    }

    private func editionChip(_ edition: WantedEdition) -> some View {
        HStack(spacing: 6) {
            StatusDot(token: WantedStateToken.token(edition.state), size: 6)
            Text(edition.tier.chipLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(Theme.isMono ? Theme.tierFill(edition.tier) : edition.tier.color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
        .fixedSize()
        .accessibilityLabel("\(edition.tier.chipLabel) · \(WantedLogic.stateLabel(edition.state))")
    }

    private var detailRow: some View {
        HStack(spacing: 10) {
            Button {
                model.open(item.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.right.square").font(.system(size: 14))
                    Text("Open in library")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if tab == .missing || tab == .cutoff { searchModeMenu }
            ActMoreMenu {
                Button("Why this decision", systemImage: "list.bullet") { model.open(item.id) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// `SearchModeMenu`: Search all / Search missing only / Search each episode.
    private var searchModeMenu: some View {
        Menu {
            Button { run(label: item.title, key: "title") } label: {
                Text("Search all")
                Text("Every monitored version of this title — pack-preferred, missing + upgrades.")
            }
            if item.kind == .series {
                Button { Task { await startGradual(label: "\(item.title) (missing only)", missingOnly: true) } } label: {
                    Text("Search missing only")
                    Text("One at a time (~\(interval)s apart) in the background. Just this title’s missing episodes.")
                }
                Button { Task { await startGradual(label: item.title, missingOnly: false) } } label: {
                    Text("Search each episode")
                    Text("Missing episodes plus any below cutoff, one at a time, ~\(interval)s apart.")
                }
            } else {
                Button { run(label: "\(item.title) (missing only)", key: "title", missingOnly: true) } label: {
                    Text("Search missing only")
                    Text("Just this title’s gaps. No upgrade re-checks.")
                }
            }
        } label: {
            ZStack {
                if searchingKey == "title" {
                    ProgressView().controlSize(.mini).tint(Theme.indigo)
                } else {
                    Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.mut)
            .frame(width: 30, height: 30)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Search for \(item.title)")
    }

    private func episodeRow(_ ep: WantedEpisode) -> some View {
        let key = "ep-\(ep.seasonNumber)-\(ep.episodeNumber)"
        return HStack(spacing: 12) {
            Text(ep.code)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .frame(minWidth: 58, alignment: .leading)
            Text(ep.title ?? "—")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let air = ep.airDate {
                Text(ActFmt.releaseDate(air)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).fixedSize()
            }
            ActIconButton(systemImage: "magnifyingglass", label: "Search for \(item.title) \(ep.code)", tint: Theme.mut,
                          busy: searchingKey == key) {
                run(label: "\(item.title) \(ep.code)", key: key, episodeId: ep.id)
            }
            .padding(.vertical, -7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func run(label: String, key: String, episodeId: Int? = nil, missingOnly: Bool = false) {
        searchingKey = key
        Task {
            defer { searchingKey = nil }
            do {
                try await model.client?.runSearch(itemId: item.id, episodeId: episodeId, missingOnly: missingOnly)
                toaster.show("Searching for \(label)")
            } catch {
                toaster.error(error)
            }
        }
    }

    private func startGradual(label: String, missingOnly: Bool) async {
        guard let client = model.client else { return }
        do {
            let start = try await client.startGradualSearch(itemId: item.id, missingOnly: missingOnly)
            gradualTotal = start.total
            if start.total == 0 {
                toaster.show(missingOnly ? "\(label): no missing episodes — nothing to search"
                                         : "\(label): all episodes meet the cutoff — nothing to upgrade", tone: .warning)
            } else if let runId = start.runId {
                withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { gradualRun = runId }
            }
        } catch let error as APIError where error.status == 409 && error.detailRunId != nil {
            withAnimation(reduce ? nil : .easeOut(duration: 0.2)) { gradualRun = error.detailRunId }
        } catch {
            toaster.show("Couldn't start the gradual search for \(label)", tone: .error)
        }
    }
}

/// `SeasonGradualProgress` for a whole title: "Searching episode n of N · next in Ns",
/// a bar and Stop. Polls the run every 1.5s until it settles.
