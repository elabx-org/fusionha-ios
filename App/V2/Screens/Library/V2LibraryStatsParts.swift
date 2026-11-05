import SwiftUI
import FusionhaKit

/// The numbers v2's stats page reads (mock browse-lib.js `statsBody`), from
/// the titles the Library's filters left: files on disk for health, 4K
/// titles for coverage, versions on disk and bytes for On disk.
struct V2LibraryNumbers {
    var titles = 0
    var uhdTitles = 0
    var filesHave = 0
    var filesTotal = 0
    var versionsDone = 0
    var versions = 0
    var bytes: Double = 0
    var attention = 0

    init() {}

    init(_ items: [MediaItem]) {
        titles = items.count
        for item in items {
            if item.editions.contains(where: { $0.tier == .uhd }) { uhdTitles += 1 }
            if item.hasAttention == true { attention += 1 }
            bytes += item.totalSize
            for edition in item.editions {
                filesHave += edition.have ?? 0
                filesTotal += edition.total ?? 0
                versions += 1
                if edition.status == .downloaded || edition.status == .upgrading { versionsDone += 1 }
            }
        }
    }
}

/// One status pill (`.spill`): the count large over a dot and the word.
/// Tapping sets the grid's status filter; tapping the active one clears it.
struct V2StatPill: View {
    let key: LibraryStatus
    let label: String
    let count: Int
    let color: Color
    @Binding var status: LibraryStatus
    var onPick: () -> Void = {}

    var body: some View {
        let active = status == key
        Button {
            status = active ? .all : key
            onPick()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(count.formatted())
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.txt)
                    .contentTransition(.numericText())
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(active ? color.opacity(0.14) : Theme.txt.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(count) \(label)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Library health, 4K coverage and On disk (`.meter`): a caption with
/// "X of Y … · N" trailing, over a 6pt bar. `grown` grows the bars on appear.
struct V2StatsMeters: View {
    let numbers: V2LibraryNumbers
    let grown: Bool

    var body: some View {
        let n = numbers
        VStack(spacing: 10) {
            meter("Library health", have: n.filesHave, of: n.filesTotal, color: Theme.done,
                  value: "\(n.filesHave.formatted()) of \(n.filesTotal.formatted()) files · \(percent(n.filesHave, n.filesTotal))")
            meter("4K coverage", have: n.uhdTitles, of: n.titles, color: Theme.grab,
                  value: "\(n.uhdTitles.formatted()) of \(n.titles.formatted()) titles · \(percent(n.uhdTitles, n.titles))")
            meter("On disk", have: n.versionsDone, of: n.versions, color: Theme.primary,
                  value: "\(n.versionsDone.formatted()) of \(n.versions.formatted()) versions · \(Format.bytes(n.bytes))")
        }
    }

    private func percent(_ a: Int, _ b: Int) -> String {
        guard b > 0 else { return "—" }
        let p = (Double(a) / Double(b) * 1000).rounded() / 10
        return p == p.rounded() ? "\(Int(p))%" : "\(p.formatted())%"
    }

    private func meter(_ caption: String, have: Int, of total: Int, color: Color, value: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(caption).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { geo in
                Rectangle()
                    .fill(color)
                    .frame(width: grown && total > 0 ? geo.size.width * CGFloat(have) / CGFloat(total) : 0)
            }
            .frame(height: 6)
            .background(Theme.txt.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }
}

/// `.conn`: an 8pt dot with a 3pt halo (green when connected, red when
/// offline, dim otherwise), the words, and the server version trailing.
struct V2ConnectionLine: View {
    let connection: ConnectionLine
    var version: String?

    var body: some View {
        let dot: Color = connection == .ok ? Theme.done : connection == .offline ? Theme.danger : Theme.dim
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 8, height: 8)
                .background(Circle().stroke(dot.opacity(0.25), lineWidth: 3).padding(-1.5))
            Text(connection.label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            if let version {
                Text("fusionha \(version)")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
