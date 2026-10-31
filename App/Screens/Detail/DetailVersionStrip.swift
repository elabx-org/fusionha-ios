import SwiftUI
import FusionhaKit

/// The hero's version strip (D4, owner-approved with the web session): one
/// chip per tracked version under the title and meta line, on the page's
/// solid ground below the art (never on it). Each chip is the lit tier pill
/// (HD purple, 4K cyan), the status glyph and the current quality / edition,
/// with the state word (`42%`, `wanted`, `needs you`) tinted through
/// `EditionStatus.color`. Tapping one opens the Files tab on that version's
/// row and lights it briefly (`DetailRevealScroll`).
struct DetailVersionStrip: View {
    @Environment(DetailStore.self) private var store

    var body: some View {
        let chips = store.stripChips
        if !chips.isEmpty {
            FlowRow(spacing: 6, lineSpacing: 8) {
                ForEach(chips) { chip in
                    Button { store.revealVersion(chip.editionId) } label: {
                        VersionStripChipView(chip: chip)
                    }
                    .buttonStyle(DetailPressStyle())
                    .accessibilityLabel(chip.text)
                    .accessibilityHint("Shows this version in Files")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .detailAnimation(.snappy(duration: 0.3), value: chips)
        }
    }
}

/// One strip chip: tier pill · status glyph · quality / edition · state word.
struct VersionStripChipView: View {
    let chip: VersionStripChip

    /// The title without the tier word the pill already shows: `2160p Remux`.
    private var rest: String {
        let word = VersionStrip.tierWord(chip.tier)
        guard chip.title.hasPrefix(word) else { return chip.title }
        return String(chip.title.dropFirst(word.count)).replacingOccurrences(of: "^ · ", with: "", options: .regularExpression)
    }

    /// The status, readable in every palette (deepened toward the text colour,
    /// like the hero's status chip); plain text under Monochrome.
    private var ink: Color { Theme.isMono ? Theme.txt : chip.status.color.mix(0.6, Theme.txt) }

    private var glyph: String { chip.held ? "hand.raised.fill" : chip.status.versionGlyph }

    var body: some View {
        HStack(spacing: 6) {
            TierPill(tier: chip.tier)
            Image(systemName: glyph)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ink)
            if !rest.isEmpty {
                Text(rest)
                    .foregroundStyle(Theme.txt)
            }
            if let detail = chip.detail {
                Text(detail)
                    .foregroundStyle(ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .frame(minHeight: 32)
        .actWash(chip.status.color, mono: chip.status.monoToken, radius: 999, base: Theme.card)
        // A 44pt target over the 32pt chip (the strip's line gap absorbs it).
        .contentShape(Rectangle().inset(by: -6))
    }
}

/// The strip's tap, carried out on the page: wait for the Files pane to lay
/// out, scroll its row into view (instantly under Reduce Motion), light it,
/// then let it fade.
@MainActor
enum DetailRevealScroll {
    static func run(_ reveal: VersionReveal, store: DetailStore, proxy: ScrollViewProxy, reduce: Bool) async {
        try? await Task.sleep(for: .milliseconds(reduce ? 60 : 220))
        guard store.versionReveal?.id == reveal.id else { return }
        // Just under the bar, which floats over the top of the page.
        let anchor = UnitPoint(x: 0.5, y: 0.16)
        if reduce {
            proxy.scrollTo(reveal.anchor, anchor: anchor)
        } else {
            withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(reveal.anchor, anchor: anchor) }
        }
        store.highlightedEditionId = reveal.editionId
        try? await Task.sleep(for: .seconds(1.6))
        if store.versionReveal?.id == reveal.id { store.highlightedEditionId = nil }
    }
}

extension View {
    /// Lights a version's row while the strip reveals it: a ring and a faint
    /// wash in its tier colour (text colour under Monochrome).
    func versionHighlight(_ edition: DetailEdition, radius: CGFloat = 20) -> some View {
        modifier(VersionHighlight(editionId: edition.id, tier: edition.tier, radius: radius))
    }
}

private struct VersionHighlight: ViewModifier {
    @Environment(DetailStore.self) private var store
    let editionId: Int
    let tier: QualityTier
    let radius: CGFloat

    func body(content: Content) -> some View {
        let lit = store.highlightedEditionId == editionId
        let color = Theme.isMono ? Theme.txt : tier.color
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .overlay {
                shape.fill(color.opacity(0.08))
                    .overlay(shape.strokeBorder(color, lineWidth: 2))
                    .opacity(lit ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .detailAnimation(.easeInOut(duration: 0.35), value: lit)
    }
}
