import SwiftUI
import FusionhaKit

/// The wide History (web `RequestsHistory` desktop, `HistoryHeader` +
/// `HistoryRow`): one bordered table, Title · Who · Status · Ready in, on the
/// web's `2fr 1.2fr 130px 80px` tracks. The status is a coloured word, never
/// a pill; the whole row opens the thread. Scrolls inside its panel (DU4).
struct HistoryTableView: View {
    let items: [MediaRequest]
    let hasMore: Bool
    let loadingMore: Bool
    let onLoadMore: () -> Void
    let onOpen: (MediaRequest) -> Void

    var body: some View {
        GeometryReader { proxy in
            let cols = HistoryColumns(width: proxy.size.width, fold: FoldInfo.verticalFold(proxy))
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, r in
                            if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                            Button { onOpen(r) } label: { row(r, cols) }.buttonStyle(.plain)
                        }
                    } header: {
                        header(cols)
                    }
                }
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
                if hasMore {
                    Button(loadingMore ? "Loading…" : "Load more", action: onLoadMore)
                        .buttonStyle(.discover(.subtle))
                        .disabled(loadingMore)
                        .padding(.vertical, 14)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func header(_ cols: HistoryColumns) -> some View {
        HStack(spacing: HistoryColumns.gap) {
            label("Title").frame(width: cols.title, alignment: .leading).padding(.trailing, cols.titleTrailing)
            label("Who").frame(width: cols.who, alignment: .leading)
            label("Status").frame(width: HistoryColumns.status, alignment: .leading)
            label("Ready in").frame(width: HistoryColumns.ready, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2)
        .accessibilityHidden(true)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.66).foregroundStyle(Theme.dim)
    }

    private func row(_ r: MediaRequest, _ cols: HistoryColumns) -> some View {
        let title = r.title ?? "TMDB #\(r.tmdbId)"
        let word = HistoryWord(r)
        let ready = RequestBoard.timeToAvailable(r)
        return HStack(spacing: HistoryColumns.gap) {
            HStack(spacing: 10) {
                ActPoster(url: r.poster, title: title, size: .sm)
                    .frame(width: 28, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm * 0.6, style: .continuous))
                (Text(title).fontWeight(.semibold).foregroundColor(Theme.txt)
                 + Text(verbatim: r.year.map { " (\($0))" } ?? "").fontWeight(.medium).foregroundColor(Theme.mut))
                    .font(.system(size: 14)).lineLimit(1)
            }
            .frame(width: cols.title, alignment: .leading)
            .padding(.trailing, cols.titleTrailing)
            Text(Self.who(r)).lineLimit(1).frame(width: cols.who, alignment: .leading)
            Text(word.text).fontWeight(.semibold).foregroundStyle(word.color).lineLimit(1)
                .frame(width: HistoryColumns.status, alignment: .leading)
            Text(ready).monospacedDigit().lineLimit(1).frame(width: HistoryColumns.ready, alignment: .leading)
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the conversation")
    }

    /// "Sam Carter · Letterboxd" (web `whoLine`).
    static func who(_ r: MediaRequest) -> String {
        let word = RequestOrigin.word(r.source)
        return r.requester.map { "\($0.displayName) · \(word)" } ?? word
    }
}

/// The table's tracks: `minmax(0, 2fr) minmax(0, 1.2fr) 130px 80px`, 12 apart,
/// inside 14 pt of padding.
struct HistoryColumns {
    static let gap: CGFloat = 12
    static let status: CGFloat = 130
    static let ready: CGFloat = 80
    private(set) var title: CGFloat
    private(set) var who: CGFloat
    /// Room after the Title track beyond `gap`: the fold gutter when the Duo's
    /// fold crosses the table (Title ends before it, Who starts after it).
    var titleTrailing: CGFloat = 0

    init(width: CGFloat, fold: ClosedRange<CGFloat>? = nil) {
        let free = max(width - 28 - Self.gap * 3 - Self.status - Self.ready, 0)
        title = free * 2 / 3.2
        who = free * 1.2 / 3.2
        guard let fold else { return }
        let gap = FoldColumns.gap(around: Double(fold.lowerBound)...Double(fold.upperBound))
        let foldTitle = CGFloat(gap.lowerBound) - 14
        let extra = CGFloat(gap.upperBound - gap.lowerBound) - Self.gap
        let foldWho = free - foldTitle - extra
        guard foldTitle >= 160, foldWho >= 80 else { return }
        title = foldTitle
        who = foldWho
        titleTrailing = extra
    }
}
