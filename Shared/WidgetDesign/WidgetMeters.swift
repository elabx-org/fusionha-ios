import SwiftUI
import WidgetKit

/// A progress ring with content in the middle (a percentage). The track turns
/// faint and the arc takes the accent in tinted rendering.
struct WidgetRing<Center: View>: View {
    let fraction: Double
    let tint: Color
    var lineWidth: CGFloat = 6
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(fraction, 1))))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            center
        }
        .padding(lineWidth / 2)
    }
}

/// A capsule progress bar.
struct WidgetBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(tint)
                .frame(width: max(height, geo.size.width * CGFloat(max(0, min(fraction, 1)))))
                .widgetAccentable()
        }
        .frame(height: height)
        .background(Color.white.opacity(0.12), in: Capsule())
        .accessibilityElement()
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

/// A big rounded count with its caption underneath (`14` / `titles`).
struct WidgetNumber: View {
    let value: String
    let caption: String
    var size: CGFloat = 40
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(WidgetStyle.numeral(size))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(caption)
                .font(WidgetStyle.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// `● 2 open issues`: a status dot and a short count line.
struct WidgetDotLine: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7).widgetAccentable()
            Text(text).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.9)
        }
    }
}

/// The percentage inside a ring: `94%` with an optional caption.
struct WidgetRingLabel: View {
    let percent: Int?
    var caption: String?
    var size: CGFloat = 17

    var body: some View {
        VStack(spacing: 0) {
            Text(percent.map { "\($0)%" } ?? "–")
                .font(WidgetStyle.numeral(size))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
