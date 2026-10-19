import SwiftUI
import FusionhaKit

// MARK: - Compact table (LibraryCompactTable.tsx)

private let tableEditionsWidth: CGFloat = 128
private let tableSizeWidth: CGFloat = 52
private let tableMonitorWidth: CGFloat = 36

/// The table head: Title and Size sort the rows (`SortHeader`); a second tap
/// flips the direction.
struct LibraryTableHeader: View {
    let sort: CompactSort
    let onSort: (CompactSortColumn) -> Void

    var body: some View {
        HStack(spacing: 8) {
            sortButton("Title", .title).frame(maxWidth: .infinity, alignment: .leading)
            Text("Versions · coverage").lineLimit(1).frame(width: tableEditionsWidth, alignment: .leading)
            sortButton("Size", .size).frame(width: tableSizeWidth, alignment: .trailing)
            Color.clear.frame(width: tableMonitorWidth)
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.7)
        .textCase(.uppercase)
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
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

struct LibraryTableRow: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    let last: Bool

    private var profileNames: String {
        let ids = item.editions.compactMap(\.qualityProfileId)
        var seen = Set<Int>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.map { id in model.profileName(id) ?? "#\(id)" }.joined(separator: " · ")
    }

    var body: some View {
        let monitored = item.monitored ?? true
        Button { model.open(item.id) } label: {
            HStack(spacing: 8) {
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
                CoverageRails(item: item, inline: true, spacing: 5)
                    .frame(width: tableEditionsWidth, alignment: .leading)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableRowStyle())
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Theme.txt.opacity(0.05)).frame(height: 1).padding(.horizontal, 1) }
        }
        .overlay(TableBorder(top: false, bottom: last))
        .contextMenu { PosterActions(item: item) }
        .reveal(0, y: 7, duration: 0.38)
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

private struct TableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.04 : 0))
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
