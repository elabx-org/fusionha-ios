import SwiftUI
import FusionhaKit

/// The Library pulse's stat pills and meters (LibraryPulse.tsx `statFilters`
/// and `meters`): the same pieces in the phone's stats sheet and the wide
/// layout's inline ribbon.
enum LibraryPulseParts {
    static let order: [(LibraryStatus, String)] = [
        (.all, "titles"), (.complete, "complete"), (.downloading, "downloading"),
        (.missing, "missing"), (.upcoming, "upcoming"),
    ]
}

/// One stat pill: its status dot, the title count and the word. Tapping sets
/// the status filter (tapping the active one clears it).
struct PulseStatButton: View {
    let key: LibraryStatus
    let label: String
    let pulse: PulseStats
    @Binding var status: LibraryStatus
    var onPick: () -> Void = {}

    private var cardStatus: CardStatus? { CardStatus(rawValue: key.rawValue) }
    private var color: Color { key == .all ? Theme.mut : (cardStatus?.color ?? Theme.i2) }
    private var count: Int { key == .all ? pulse.titles : (cardStatus.flatMap { pulse.titleCounts[$0] } ?? 0) }

    var body: some View {
        let isActive = status == key
        Button {
            status = (isActive && key != .all) ? .all : key
            onPick()
        } label: {
            HStack(spacing: 9) {
                dot
                Text("\(count)").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                    .contentTransition(.numericText())
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .padding(.leading, 10)
            .padding(.trailing, 13)
            .padding(.vertical, 9)
            .background(isActive ? color.opacity(0.12) : Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(count) \(label)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder private var dot: some View {
        if Theme.isMono, let token = cardStatus?.monoToken {
            StatusGlyph(token: token, size: 11).frame(width: 10, height: 10)
        } else if key == .downloading {
            PulsingDot(color: color, size: 10, period: 1.5)
        } else {
            Circle().fill(color).frame(width: 10, height: 10)
                .background(Circle().fill(color.opacity(0.18)).padding(-4))
        }
    }
}

/// Library health (status segments), 4K coverage and On disk. `grown` lets
/// the bars grow from zero on appear.
struct PulseMeters: View {
    let pulse: PulseStats
    let grown: Bool

    var body: some View {
        VStack(spacing: 12) {
            meter("Library health") {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach([CardStatus.complete, .downloading, .missing, .upcoming], id: \.self) { seg in
                            StatusSwatch(token: seg.monoToken, shape: Rectangle())
                                .frame(width: grown && pulse.totalEditions > 0
                                       ? geo.size.width * CGFloat(pulse.counts[seg] ?? 0) / CGFloat(pulse.totalEditions) : 0)
                        }
                    }
                }
                .frame(height: 9)
                .background(Theme.txt.opacity(0.06))
                .clipShape(Capsule())
            } value: { "\(pulse.healthPct)%" }
            meter("4K coverage") {
                GeometryReader { geo in
                    Capsule()
                        .fill(Theme.grab)
                        .frame(width: grown && pulse.titles > 0 ? geo.size.width * CGFloat(pulse.fourKTitles) / CGFloat(pulse.titles) : 0)
                }
                .frame(height: 9)
                .background(Theme.txt.opacity(0.07), in: Capsule())
            } value: { "\(pulse.fourKTitles) / \(pulse.titles) titles" }
            meter("On disk") { Spacer() } value: { Format.bytes(pulse.onDisk) }
        }
    }

    private func meter<Bar: View>(_ caption: String, @ViewBuilder bar: () -> Bar, value: () -> String) -> some View {
        HStack(spacing: 12) {
            Text(caption).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                .frame(minWidth: 96, alignment: .leading)
            bar()
            Text(value()).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.txt)
        }
    }
}
