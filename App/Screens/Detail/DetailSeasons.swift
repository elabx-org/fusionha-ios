import SwiftUI
import FusionhaKit

// The Seasons tab (SeasonsAccordion + MobileEpisodeList, redesign `.season`):
// one card per season (SeasonCard) with a striped progress bar and a glass ⋯
// sheet, then the episode rows (DetailEpisodes) inside the card.

struct SeasonsTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
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
                Text("Seasons")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dim)
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
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                            .padding(.horizontal, -4).padding(.vertical, -4)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel(allOpen ? "Collapse all seasons" : "Expand all seasons")
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 14)

            if detail.numberingMismatch == true {
                Button {
                    store.showingNumbering = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(detail.episodeNumberingSource == "tvmaze"
                             ? "Episode numbering may be off vs TVmaze. Review"
                             : "TheTVDB renumbered this show. Review")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                    .padding(12)
                    .actWash(Theme.miss, mono: .miss, radius: 10)
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
