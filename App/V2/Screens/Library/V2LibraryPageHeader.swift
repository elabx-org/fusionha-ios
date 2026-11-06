import SwiftUI
import FusionhaKit

/// The top of the v2 Library (approved mock, browse.js home 'live'): row 1 is
/// the title, the counts line and the kind control; row 2 the chip row, then
/// any set filters as tokens. Wide (the open Duo, a pane of 700 or more) the
/// title is on the page with the counts beside it and the kind control at
/// the trailing end, so the bar's own title is blank
/// (`titleInPage`); book pose splits that line at the fold. Narrower, the
/// bar keeps the large title and the counts and kind control stack under it.
/// Filter and Sort are in the bar (`V2LibraryFilterMenu`); the library filter
/// is the pull-down search field (`V2LibrarySearch`).
struct V2LibraryPageHeader: View {
    let derived: LibraryDerived
    let filters: V2LibraryFilters
    let paneWidth: CGFloat
    @Environment(\.bookPose) private var bookPose
    @Environment(\.pagePalette) private var page

    /// The page draws the title (the bar's is blank) at this width and up.
    static func titleInPage(paneWidth: CGFloat) -> Bool { paneWidth >= 700 }

    private var wide: Bool { Self.titleInPage(paneWidth: paneWidth) }
    private var showsAnime: Bool { (derived.kindTitles[.anime] ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .reveal(0)
            V2LibraryFilterRow(filters: filters, showsAnime: showsAnime)
                .padding(.top, 12)
                .reveal(1)
            V2LibraryFilterTokens(filters: filters)
                .padding(.top, filters.rowTokens.isEmpty ? 0 : 10)
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        let kinds = V2LibraryKindControl(derived: derived, kind: filters.$kind)
        if wide && bookPose {
            FoldSpanRow(trailingAlignment: .center) { heading } trailing: { kinds }
        } else if wide {
            // One line when it fits; else the kind control drops under the title.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 0) {
                    heading.fixedSize()
                    Spacer(minLength: 20)
                    kinds.frame(width: 420)
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    kinds.frame(maxWidth: 520)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                V2LibraryStatsLine(derived: derived, kind: filters.kind)
                kinds
            }
        }
    }

    /// "All titles" at the system large-title size, the counts on its baseline.
    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("All titles")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(1)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            V2LibraryStatsLine(derived: derived, kind: filters.kind)
        }
    }
}

/// The kind control (v2 header): All, Movies, Series, Anime (Animation when
/// the library has some) as one glass segmented control in one ink. No kind
/// dots and no make-up bar; the counts line says how many.
struct V2LibraryKindControl: View {
    let derived: LibraryDerived
    @Binding var kind: String

    private var options: [(String, String)] {
        let kinds = KindControl.kinds(titles: derived.kindTitles, active: LibraryKind(rawValue: kind))
        return [("all", "All")] + kinds.map { ($0.rawValue, $0.plural) }
    }

    var body: some View {
        // Every label whole: equal segments when they fit, else a sideways
        // row (Animation joining on a phone would truncate the fill form).
        ViewThatFits(in: .horizontal) {
            SegmentedPills(options: options, selection: $kind, fill: true)
            ScrollView(.horizontal, showsIndicators: false) {
                SegmentedPills(options: options, selection: $kind)
            }
            .scrollClipDisabled()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kind")
    }
}

/// The counts line (browse-lib.js `statsLine`): "843 titles · 4,927
/// versions", "312 movies · 181 in 4K" or "96 anime · 40 animation", then
/// the downloads in the accent, linked to Activity.
struct V2LibraryStatsLine: View {
    let derived: LibraryDerived
    let kind: String
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var noun: String {
        let n = derived.titleCount
        guard let k = LibraryKind(rawValue: kind) else { return n == 1 ? "title" : "titles" }
        return n == 1 && k != .series && k != .anime && k != .animation ? String(k.plural.lowercased().dropLast())
            : k.plural.lowercased()
    }

    private var summary: String {
        let t = derived.titleCount.formatted()
        switch LibraryKind(rawValue: kind) {
        case .movie?:
            return "\(t) \(noun) · \(derived.pulse.fourKTitles.formatted()) in 4K"
        case .anime?:
            return "\(t) \(noun) · \((derived.kindTitles[.animation] ?? 0).formatted()) animation"
        default:
            let e = derived.editionCount
            return "\(t) \(noun) · \(e.formatted()) \(e == 1 ? "version" : "versions")"
        }
    }

    var body: some View {
        let downloading = derived.pulse.titleCounts[.downloading] ?? 0
        HStack(spacing: 0) {
            Text(summary)
                .contentTransition(.numericText())
            if downloading > 0 {
                Text(verbatim: " · ")
                Button { model.tab = .activity } label: {
                    Text("\(downloading) downloading").foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.plain)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .font(.system(size: 13).monospacedDigit())
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
    }
}
