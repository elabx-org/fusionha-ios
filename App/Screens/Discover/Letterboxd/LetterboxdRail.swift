import SwiftUI
import FusionhaKit

/// Discover › Browse "From your Letterboxd" (web `SuggestionsRail`): titles
/// from the viewer's Letterboxd watchlist and linked lists that aren't in the
/// library or requested yet, each with its own Request. Gated on a connected
/// profile or a linked source, so Discover never shifts for anyone else.
struct LetterboxdRail: View {
    @Environment(AppModel.self) private var model
    let canAdd: Bool
    let canRequest: Bool
    @State private var letterboxd: LetterboxdRead?
    @State private var base: SuggestionsRead?
    @State private var baseFailed = false
    @State private var filtered: SuggestionsRead?
    @State private var sourceId: Int?
    @State private var quota: RequestQuota?

    /// The selected source's read; nil while it loads (the skeleton shows).
    private var shown: SuggestionsRead? { sourceId == nil ? base : filtered }

    var body: some View {
        VStack(spacing: 0) {
            if let base, base.visible {
                rail(base)
                    .task(id: sourceId) { await loadFiltered() }
            } else if base == nil, !baseFailed, SuggestionRail.gated(letterboxd) {
                SuggestionSkeleton().padding(.bottom, 34)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await load() }
    }

    private func rail(_ base: SuggestionsRead) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            let chips = SuggestionRail.chips(base)
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    DiscoverSegmented(options: chips.map { ($0.sourceId, $0.text) }, selection: $sourceId)
                }
                .scrollClipDisabled()
            }
            track
            footer(base)
                .foldLeadingColumn()
        }
        .padding(.bottom, 34)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                LetterboxdMarkTile()
                Text(SuggestionRail.heading)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            if let quota { SuggestionQuotaPip(quota: quota) }
        }
    }

    @ViewBuilder
    private var track: some View {
        if let shown {
            if shown.items.isEmpty {
                Text(SuggestionRail.empty)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foldLeadingColumn()
            } else {
                RailTrack(count: shown.items.count, cell: SuggestionCard.width, fixed: true) {
                    ForEach(Array(shown.items.enumerated()), id: \.element.id) { index, item in
                        SuggestionCard(item: item, overLimit: SuggestionRail.overLimit(quota),
                                       uhdAllowed: letterboxd?.alsoUhdAllowed ?? false,
                                       actionable: canRequest || canAdd,
                                       onDone: { Task { await loadQuota() } })
                            .discoverReveal(index: index)
                    }
                }
            }
        } else {
            SuggestionSkeleton()
        }
    }

    private func footer(_ base: SuggestionsRead) -> some View {
        let hint = SuggestionRail.hintText(itemCount: shown?.items.count ?? 0,
                                           staleSources: SuggestionRail.staleSources(base.items))
        return VStack(alignment: .leading, spacing: 4) {
            if let hint {
                Text(hint).font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            Button(SuggestionRail.manage) { model.openAutomaticRequests() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        if letterboxd == nil, let kept = await client.cached({ try await $0.letterboxd() }) { letterboxd = kept }
        if base == nil, let kept = await client.cached({ try await $0.suggestions() }) { base = kept }
        if let fresh = try? await client.letterboxd() { letterboxd = fresh }
        do {
            base = try await client.suggestions()
        } catch {
            if base == nil { baseFailed = true }
        }
        await loadQuota()
    }

    private func loadQuota() async {
        guard let client = model.client else { return }
        if let fresh = try? await client.requestQuota() { quota = fresh }
    }

    private func loadFiltered() async {
        guard let sourceId, let client = model.client else {
            filtered = nil
            return
        }
        filtered = nil
        filtered = try? await client.suggestions(sourceId: sourceId)
    }
}
