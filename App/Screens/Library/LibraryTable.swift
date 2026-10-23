import SwiftUI
import FusionhaKit

// MARK: - Compact table (LibraryCompactTable.tsx)

private let tableEditionsWidth: CGFloat = 128
private let tableSizeWidth: CGFloat = 52
private let tableMonitorWidth: CGFloat = 36

/// The table head: Title and Size sort the rows (`SortHeader`); a second tap
/// flips the direction. With the iPhone Duo's fold through the table (Web
/// layout, `LibraryFold.table`) it is two heads meeting at the fold's gutter.
struct LibraryTableHeader: View {
    let sort: CompactSort
    var split: FoldColumns.Panes?
    let onSort: (CompactSortColumn) -> Void

    var body: some View {
        if let split {
            FoldPairLayout(lead: CGFloat(split.lead), gap: CGFloat(split.gap), fillHeight: true) {
                head { titleHead }
                head { metricsHead }
            }
        } else {
            head {
                HStack(spacing: 8) {
                    titleHead
                    metricsHead.frame(width: tableEditionsWidth + tableSizeWidth + tableMonitorWidth + 16)
                }
            }
        }
    }

    private var titleHead: some View {
        sortButton("Title", .title).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsHead: some View {
        HStack(spacing: 8) {
            Text("Versions · coverage").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            sortButton("Size", .size).frame(width: tableSizeWidth, alignment: .trailing)
            Color.clear.frame(width: tableMonitorWidth)
        }
    }

    private func head<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.system(size: 11, weight: .bold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .frame(maxHeight: .infinity)
            .background(Theme.panel, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
            .overlay(TableBorder(top: true, bottom: false))
    }

    private func sortButton(_ label: String, _ column: CompactSortColumn) -> some View {
        let active = sort.column == column
        return Button { onSort(column) } label: {
            HStack(spacing: 3) {
                Text(label)
                Text(active && sort.ascending ? "▴" : "▾")
                    .foregroundStyle(active ? Theme.accentText : Theme.dim)
            }
            .foregroundStyle(active ? Theme.txt : Theme.mut)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort by \(label)")
        .accessibilityValue(active ? (sort.ascending ? "Ascending" : "Descending") : "")
    }
}

/// One title in the compact table. Split at the fold (Web layout), the poster
/// and title end before the gutter and the versions, size and monitor start
/// after it, each piece with its own card edge; nothing is drawn in the gap.
struct LibraryTableRow: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    let last: Bool
    var split: FoldColumns.Panes?

    private var profileNames: String {
        let ids = item.editions.compactMap(\.qualityProfileId)
        var seen = Set<Int>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.map { id in model.profileName(id) ?? "#\(id)" }.joined(separator: " · ")
    }

    var body: some View {
        Button { model.open(item.id) } label: {
            if let split {
                FoldPairLayout(lead: CGFloat(split.lead), gap: CGFloat(split.gap), fillHeight: true) {
                    cell { titleCell }
                    cell { metricsCell(coverage: .infinity) }
                }
            } else {
                cell {
                    HStack(spacing: 8) {
                        titleCell
                        metricsCell(coverage: tableEditionsWidth)
                    }
                }
            }
        }
        .buttonStyle(TableRowStyle(gap: split.map { CGFloat($0.lead)...CGFloat($0.lead + $0.gap) }))
        .contextMenu { PosterActions(item: item) }
        .reveal(0, y: 7, duration: 0.38)
    }

    private var titleCell: some View {
        HStack(spacing: 9) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .frame(width: 34, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                Text(subline).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Versions · coverage, size and the monitor mark (`bookmark`).
    private func metricsCell(coverage: CGFloat) -> some View {
        let monitored = item.monitored ?? true
        return HStack(spacing: 8) {
            CoverageRails(item: item, inline: true, spacing: 5)
                .frame(maxWidth: coverage, alignment: .leading)
                .frame(width: coverage.isFinite ? coverage : nil, alignment: .leading)
            Text(Format.bytes(item.totalSize))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .frame(width: tableSizeWidth, alignment: .trailing)
            Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14))
                .foregroundStyle(monitored ? Theme.i2 : Theme.mut.opacity(0.5))
                .frame(width: tableMonitorWidth)
        }
    }

    /// One piece of the row: padded, with the row's hairline and the table's edge.
    private func cell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !last { Rectangle().fill(Theme.txt.opacity(0.05)).frame(height: 1).padding(.horizontal, 1) }
            }
            .overlay(TableBorder(top: false, bottom: last))
    }

    private var subline: String {
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        parts.append(item.kind == .movie ? "Movie" : "Series")
        if item.isAnime == true { parts.append("Anime") }
        let profiles = profileNames
        if !profiles.isEmpty { parts.append(profiles) }
        return parts.joined(separator: " · ")
    }
}

/// The pressed tint, kept out of the fold's gap when the row is split.
private struct TableRowStyle: ButtonStyle {
    var gap: ClosedRange<CGFloat>?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.04 : 0), in: FoldGapShape(gap: gap))
    }
}

/// The table's outer hairline, drawn per row so the rows stay lazy.
private struct TableBorder: View {
    let top: Bool
    let bottom: Bool

    var body: some View {
        TableBorderShape(top: top, bottom: bottom, radius: 14)
            .stroke(Theme.line, lineWidth: 1)
    }
}

private struct TableBorderShape: Shape {
    let top: Bool
    let bottom: Bool
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.5, dy: 0)
        var p = Path()
        if top {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
            p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
            p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius,
                     startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        } else if bottom {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - radius))
            p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                     startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: r.maxX - radius, y: r.maxY))
            p.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius,
                     startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        }
        return p
    }
}
