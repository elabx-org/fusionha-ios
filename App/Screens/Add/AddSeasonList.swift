import SwiftUI
import FusionhaKit

/// The phone season list: one row per season (name · tick bar · lit/total),
/// "Show all" past eight seasons, the slider hint and a "New episodes" row.
struct AddSeasonList: View {
    let flow: AddFlow
    let seasons: [SeasonCounts]
    let bars: [AddSeasonBar]
    let disabled: Bool
    let anime: Bool
    let customised: SeasonFrom
    @State private var expanded = false

    private static let collapseOver = 8
    private static let collapsedRows = 6
    private static let sliderHint = "Press and hold a season, then slide to choose where monitoring starts. Tap a season’s name to switch it all on or off."
    private static let splitHint = "Switch to Same for both versions to adjust seasons"
    private static let animeHint = "Season adjusting is off for anime: its episode numbering can differ once added"

    var body: some View {
        let regular = seasons.filter { $0.seasonNumber > 0 }.count
        let collapsible = regular > Self.collapseOver
        let shown = collapsible && !expanded ? Array(seasons.prefix(Self.collapsedRows)) : seasons
        let watchesNew = bars.contains { $0.preview.newEpisodes }
        VStack(alignment: .leading, spacing: 0) {
            LazyVStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.seasonNumber) { index, season in
                    AddSeasonRow(season: season, index: index, bars: bars, disabled: disabled,
                                 custom: customised[season.seasonNumber] != nil,
                                 onToggle: { flow.toggleSeason(season.seasonNumber) },
                                 onCommit: { from in
                                     flow.setSeasonStart(season.seasonNumber,
                                                         SeasonSlider.start(from0: from, episodeCount: max(0, season.episodeCount)))
                                 })
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
            }
            if collapsible {
                Button(expanded ? "Show fewer seasons" : "Show all \(regular) seasons") { expanded.toggle() }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.i2)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            Text(disabled ? (anime ? Self.animeHint : Self.splitHint) : Self.sliderHint)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.mut)
                .lineSpacing(3)
                .padding(.top, 6)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            HStack(spacing: 10) {
                Text("New episodes").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                    .frame(width: 96, alignment: .leading)
                Text(watchesNew ? "monitored as they air" : "not monitored")
                    .font(.system(size: 12))
                    .foregroundStyle(watchesNew ? Theme.txt : Theme.dim)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
        }
    }
}

/// One season: its name (a whole-season toggle), one tick bar per version,
/// and "lit/total". Hold, then slide across the row, to set where it starts.
struct AddSeasonRow: View {
    let season: SeasonCounts
    let index: Int
    let bars: [AddSeasonBar]
    let disabled: Bool
    let custom: Bool
    let onToggle: () -> Void
    let onCommit: (Int) -> Void
    @Environment(\.motionEnabled) private var motion
    @State private var trackWidth: CGFloat = 1
    @State private var trackX: CGFloat = 0
    /// While sliding: the 0-based first lit episode and the finger's ratio.
    @State private var sliding: (from: Int, ratio: Double)?

    private var n: Int { max(0, season.episodeCount) }
    private var name: String { season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)" }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                (Text(name) + (custom ? Text(" •").foregroundColor(Theme.i2) : Text("")))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(season.seasonNumber == 0 ? Theme.anime : Theme.mut)
                    .lineLimit(1)
                    .frame(width: 76, alignment: .leading)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .accessibilityLabel("\(name)\(custom ? " (adjusted)" : ""): switch the whole season on or off")
            VStack(spacing: 5) {
                ForEach(Array(bars.enumerated()), id: \.offset) { bi, bar in
                    let lit = litSet(bar, first: bi == 0)
                    HStack(spacing: 8) {
                        if bars.count > 1 {
                            Text(bar.label)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(bar.tier.color)
                        }
                        AddSeasonTicks(count: n, lit: lit, color: bar.tier.color, active: sliding != nil && bi == 0)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("seasonRow")) } action: { frame in
                                if bi == 0 {
                                    trackWidth = max(1, frame.width)
                                    trackX = frame.minX
                                }
                            }
                        Text("\(lit.count)/\(n)")
                            .font(.system(size: 11, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(Theme.mut)
                            .frame(width: 42, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(bars.count > 1 ? "\(bar.label) " : "")\(name): \(lit.count) of \(n) monitored")
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        .coordinateSpace(.named("seasonRow"))
        .background {
            if sliding != nil {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.i2.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.i2.opacity(0.35)))
            }
        }
        .scaleEffect(sliding != nil && motion ? 1.03 : 1)
        .overlay(alignment: .topLeading) {
            if let sliding {
                Text(SeasonSlider.bubble(from: sliding.from, episodeCount: n))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.onFill(hex: Theme.palette.i2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.i2, in: Capsule())
                    .fixedSize()
                    .position(x: trackX + trackWidth * min(0.88, max(0.12, sliding.ratio)), y: -14)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(sliding != nil ? 2 : 0)
        .animation(motion ? .easeOut(duration: 0.25) : nil, value: sliding != nil)
        .gesture(slider, isEnabled: !disabled)
        .sensoryFeedback(.impact(weight: .light), trigger: sliding != nil)
        .sensoryFeedback(.selection, trigger: sliding?.from)
    }

    private func litSet(_ bar: AddSeasonBar, first: Bool) -> Set<Int> {
        if first, let sliding { return Set(sliding.from..<max(sliding.from, n)) }
        return Set(index < bar.preview.perSeason.count ? bar.preview.perSeason[index].lit : [])
    }

    private func ratio(_ x: CGFloat) -> Double { Double((x - trackX) / trackWidth) }

    private var slider: some Gesture {
        LongPressGesture(minimumDuration: 0.32, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("seasonRow")))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    let r = drag.map { ratio($0.location.x) } ?? sliding?.ratio ?? 0
                    let clamped = min(1, max(0, r))
                    sliding = (SeasonSlider.from(ratio: clamped, episodeCount: n), clamped)
                default:
                    break
                }
            }
            .onEnded { _ in
                if let sliding { onCommit(sliding.from) }
                sliding = nil
            }
    }
}

/// One season's ticks (or a single bar past 60 episodes), drawn in a Canvas.
struct AddSeasonTicks: View {
    let count: Int
    let lit: Set<Int>
    let color: Color
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let off = Theme.txt.opacity(0.08)
            if count > 60 {
                let bar = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3)
                context.fill(bar, with: .color(off))
                if let lo = lit.min(), !lit.isEmpty {
                    let x = size.width * CGFloat(lo) / CGFloat(count)
                    let w = size.width * CGFloat(lit.count) / CGFloat(count)
                    context.fill(Path(roundedRect: CGRect(x: x, y: 0, width: w, height: size.height), cornerRadius: 3),
                                 with: .color(color))
                }
                return
            }
            guard count > 0 else { return }
            let gap: CGFloat = 2
            let w = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            for e in 0..<count {
                let rect = CGRect(x: CGFloat(e) * (w + gap), y: 0, width: w, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(lit.contains(e) ? color : off))
            }
        }
        .frame(height: active ? 18 : 12)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
