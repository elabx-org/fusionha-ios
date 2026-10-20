import SwiftUI
import FusionhaKit

// The downloads bar's pieces. The bar itself is system glass (a control);
// the poster thumb inside it is content.

/// The lead download's poster, small and solid.
struct DownloadsBarThumb: View {
    let url: String?
    var compact = false

    var body: some View {
        PosterImage(url: TMDBImage.resized(url, to: "w92"))
            .frame(width: compact ? 20 : 26, height: compact ? 30 : 38)
            .shelfPoster(radius: compact ? 4 : 6, shadow: false)
            .accessibilityHidden(true)
    }
}

/// The needs-you "!" or the done tick, in a filled circle of the state's colour.
/// Monochrome reads the state from the symbol and the words, not the hue.
struct DownloadsBarSymbol: View {
    enum Kind { case needsYou, done }
    let kind: Kind
    var compact = false

    var body: some View {
        let hex = kind == .needsYou ? Theme.palette.stuck : Theme.palette.done
        Image(systemName: kind == .needsYou ? "exclamationmark" : "checkmark")
            .font(.system(size: compact ? 11 : 14, weight: .heavy))
            .foregroundStyle(Theme.onFill(hex: hex))
            .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
            .background(Color(hex: hex), in: Circle())
            .accessibilityHidden(true)
    }
}

/// Overall progress as a ring with the percent inside.
struct DownloadsBarRing: View {
    let percent: Int
    var size: CGFloat = 36

    var body: some View {
        let width: CGFloat = size >= 34 ? 3 : 2.5
        ZStack {
            Circle().stroke(Theme.line, lineWidth: width)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(Theme.grab, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: size >= 34 ? 10 : 9, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.txt)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(value: Double(percent)))
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The lead download's own progress, a hairline along the bar's bottom edge.
struct DownloadsBarHairline: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Theme.line)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.grab).frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
        }
        .frame(height: 2.5)
        .padding(.horizontal, 18)
        .accessibilityHidden(true)
    }
}

/// The stuck / done wash: a tint from the leading edge (never a border).
struct DownloadsBarWash: View {
    let color: Color

    var body: some View {
        LinearGradient(colors: [color.opacity(0.24), color.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .clipShape(Capsule())
            .allowsHitTesting(false)
    }
}
