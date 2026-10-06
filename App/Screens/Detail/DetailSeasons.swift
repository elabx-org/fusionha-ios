import SwiftUI
import FusionhaKit

// The Seasons tab (SeasonsAccordion + MobileEpisodeList): season cards with a
// striped progress bar and a ⋮ sheet, carded episode rows with one status chip
// per scoped version, and the expanded per-version facts + actions.

struct SeasonsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let openWeb: () -> Void
    @State private var open: Set<Int>?

    /// The running `tree` step's source while the season list is still empty.
    private var waitingSource: String? {
        guard let setup = model.setupProgress.activeSetup(for: detail.id),
              let tree = setup.steps.first(where: { $0.key == "tree" }),
              tree.status == .running else { return nil }
        return tree.source ?? "the provider"
    }

    var body: some View {
        let seasons = detail.seasonsNewestFirst
        let openSet = open ?? Set(seasons.prefix(1).map(\.seasonNumber))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("SEASONS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(Theme.mut)
                Spacer(minLength: 4)
                if let e = store.enrichment, let pending = e.pendingFiles, pending > 0 {
                    AnalysisPill(status: e) {
                        model.tab = .activity
                        model.presentedItem = nil
                    }
                }
                if model.me?.can("edit") ?? true {
                    Button {
                        Task { await store.checkNumbering() }
                    } label: {
                        Image(systemName: "list.number")
                            .foregroundStyle(detail.numberingMismatch == true ? Theme.miss : Theme.mut)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel("Check episode numbering")
                }
                if seasons.count > 1 {
                    let allOpen = openSet.count == seasons.count
                    Button {
                        open = allOpen ? Set<Int>() : Set(seasons.map(\.seasonNumber))
                    } label: {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(allOpen ? 90 : 0))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel(allOpen ? "Collapse all seasons" : "Expand all seasons")
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 14)

            if detail.numberingMismatch == true {
                Button(action: openWeb) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(detail.episodeNumberingSource == "tvmaze"
                             ? "Episode numbering may be off vs TVmaze — Review"
                             : "TheTVDB renumbered this show — Review")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                    .padding(12)
                    .background(Theme.miss.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.miss.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }

            if seasons.isEmpty {
                if let source = waitingSource {
                    SeasonsWaiting(source: source)
                } else {
                    EmptyBox(message: "No seasons yet for this title.")
                }
            }
            ForEach(seasons) { season in
                SeasonCard(detail: detail, season: season, isOpen: openSet.contains(season.seasonNumber)) {
                    var next = openSet
                    if next.contains(season.seasonNumber) { next.remove(season.seasonNumber) } else { next.insert(season.seasonNumber) }
                    open = next
                }
            }
        }
    }
}

/// While the setup's `tree` step is still building the season list (TVDB-only /
/// Hybrid): a skeleton + "Waiting for seasons from TVDB…" (ItemDetail
/// `seasonsWaiting`, SeasonsAccordion `.seasonsWaiting`).
private struct SeasonsWaiting: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach([0.7, 0.9, 0.55], id: \.self) { width in
                    GeometryReader { geo in
                        SkeletonBar(height: 12, radius: 6).frame(width: geo.size.width * width)
                    }
                    .frame(height: 12)
                }
            }
            .accessibilityHidden(true)
            Text("Waiting for seasons from \(source)…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

/// "Analysing N files · P%" (AnalysisProgressPill).
private struct AnalysisPill: View {
    let status: EnrichmentStatus
    let action: () -> Void

    var body: some View {
        let pending = status.pendingFiles ?? 0
        let total = max(status.totalFiles ?? 0, 1)
        let pct = Int((Double(status.enrichedFiles ?? 0) / Double(total) * 100).rounded())
        Button(action: action) {
            HStack(spacing: 6) {
                DetailSpinner(size: 12, color: Theme.indigo, period: 0.9)
                Text("Analysing \(pending) file\(pending == 1 ? "" : "s") · \(pct)%")
                    .lineLimit(1)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Theme.indigo)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Theme.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.indigo.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Season card

struct SeasonCard: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        let editions = store.scopedEditions
        let ids = editions.map(\.id)
        let c = season.completion(editionIds: ids)
        let paused = pausedCount(ids)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Button(action: toggle) {
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.mut)
                                .rotationEffect(.degrees(isOpen ? 90 : 0))
                                .detailAnimation(.easeInOut(duration: 0.2), value: isOpen)
                            Text(season.title)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(Theme.txt)
                                .lineLimit(1)
                                .fixedSize()
                            Text("\(c.done)/\(c.total)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.mut)
                                .contentTransition(.numericText(value: Double(c.done)))
                                .detailAnimation(.easeOut(duration: 0.4), value: c.done)
                            Spacer(minLength: 4)
                            Text(DetailText.bytes(season.bytes(editionIds: ids)))
                                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(season.title), \(c.done) of \(c.total)")
                    Button {
                        store.seasonSheet = SeasonRef(number: season.seasonNumber)
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 44, height: 44)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel("\(season.title) actions")
                }
                SeasonBar(total: c.total, done: c.done, downloading: c.downloading, attention: c.attention)
                if paused > 0 {
                    Text("\(paused) cooling down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.stuck)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.stuck.opacity(0.12), in: Capsule())
                        .detailPulse(low: 0.35, high: 1, period: 2.4)
                        .accessibilityHint("Cooling down after failed downloads · a manual search runs now and ignores the cooldown")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(season.seasonNumber == 0 ? Theme.miss.opacity(0.06) : .clear)

            if isOpen {
                Rectangle().fill(Theme.line).frame(height: 1)
                EpisodeList(detail: detail, season: season)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line))
        .padding(.bottom, 12)
        .detailAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.42), value: isOpen)
    }

    private func pausedCount(_ ids: [Int]) -> Int {
        let now = DetailText.instant(store.pauses?.now) ?? Date()
        let episodeIds = Set(season.episodes.map(\.id))
        let paused = (store.pauses?.episodes ?? []).filter { p in
            guard let e = p.episodeId, episodeIds.contains(e), let ed = p.editionId, ids.contains(ed),
                  let until = DetailText.instant(p.cooldownUntil) else { return false }
            return until > now
        }
        return Set(paused.compactMap(\.episodeId)).count
    }
}

/// The 6pt season bar: present (with a stuck-coloured attention tail) then a
/// striped downloading segment over a miss-tinted track.
private struct SeasonBar: View {
    let total: Int
    let done: Int
    let downloading: Int
    let attention: Int
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let doneW = total > 0 ? w * CGFloat(done) / CGFloat(total) : 0
            let dlW = total > 0 ? w * CGFloat(downloading) / CGFloat(total) : 0
            let attentionShare = done > 0 ? Double(attention) / Double(done) : 0
            HStack(spacing: 0) {
                LinearGradient(stops: [
                    .init(color: Theme.done, location: 0),
                    .init(color: Theme.done, location: max(0, 1 - attentionShare)),
                    .init(color: Theme.stuck, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: shown ? doneW : 0)
                if downloading > 0 {
                    Theme.grab
                        .overlay(DetailStripes())
                        .frame(width: shown ? dlW : 0)
                }
                Spacer(minLength: 0)
            }
            .background(Theme.miss.mix(0.3, Color(white: 0.08)))
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .detailAnimation(DetailMotion.barFill, value: shown)
        .onAppear { shown = true }
    }
}
