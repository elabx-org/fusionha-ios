import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

// The redesign's pieces for the Live Activity: the edition chip that is its
// own progress bar (the redesign signature), the wash taken from the poster,
// the stage rail for symlink jobs, and the display-face hero.

/// An HD / 4K chip that fills left to right with `fraction`: coloured text on
/// a tinted track, dark text over the fill, so the label reads either side of
/// the edge. A full chip with a check is the "landed" state.
struct EditionFillChip: View {
    let label: String
    let color: Color
    var fraction: Double = 0
    /// Under Monochrome the fill wears this status' pattern (HD and 4K differ by shade and pattern).
    var mono: MonoToken? = nil

    var body: some View {
        chipText.foregroundStyle(color)
            .background(color.opacity(0.18), in: Capsule())
            .overlay {
                ZStack {
                    color
                    if Theme.isMono, let mono { MonoPatternFill(pattern: mono.pattern) }
                    chipText.foregroundStyle(Color.black.opacity(0.82))
                }
                .mask(alignment: .leading) {
                    GeometryReader { g in
                        Rectangle().frame(width: g.size.width * CGFloat(min(max(fraction, 0), 1)))
                    }
                }
            }
            .clipShape(Capsule())
            .fixedSize()
    }

    private var chipText: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(minWidth: 46, minHeight: 20)
    }
}

/// The display face for a state's one big number or word.
struct LiveActivityHero: View {
    let text: String
    var size: CGFloat = 34
    var color: Color = .white
    var unit: String? = nil

    var body: some View {
        (Text(text) + Text(unit ?? "").font(Theme.display(size * 0.5, relativeTo: .title2)))
            .font(Theme.display(size, relativeTo: .largeTitle))
            .tracking(Theme.displayTracking(size))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// One rail split into a symlink job's stages: done stages filled, the live
/// one glowing, the rest empty. Replaces the row of pills.
struct LiveActivityStageRail: View {
    let steps: DownloadsActivityAttributes.ContentState.Steps

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                ForEach(steps.labels.indices, id: \.self) { i in
                    stage(i)
                        .frame(height: 8)
                        .shadow(color: i == steps.done ? Theme.grab.opacity(0.6) : .clear, radius: 5)
                }
            }
            HStack {
                Text(steps.labels.first ?? "")
                Spacer(minLength: 4)
                Text([steps.current, steps.current?.lowercased().contains("link") == true ? steps.detail : nil].compactMap { $0 }.joined(separator: " "))
                    .foregroundStyle(Theme.grab)
                Spacer(minLength: 4)
                Text(steps.labels.last ?? "")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private func stage(_ i: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        if Theme.isMono && i <= steps.done {
            // Monochrome: done stages solid, the live one patterned (no gradient).
            StatusSwatch(token: i < steps.done ? .done : .grab, shape: shape, color: Theme.grab)
        } else {
            shape.fill(fill(i))
        }
    }

    private func fill(_ i: Int) -> AnyShapeStyle {
        if i < steps.done { return AnyShapeStyle(Theme.grab) }
        if i == steps.done {
            return AnyShapeStyle(Theme.grab.opacity(0.55))
        }
        return AnyShapeStyle(Color.white.opacity(0.12))
    }
}

/// The card's wash: the poster's own colour (or the state's) fading from the
/// leading edge, so every title tints its card.
struct LiveActivityWash: View {
    let state: DownloadsActivityAttributes.ContentState

    var body: some View {
        if Theme.isMono {
            MonoWash(token: LiveActivityTone.token(state), color: tint, radius: 0)
        } else {
            LinearGradient(colors: [tint.opacity(0.34), tint.opacity(0.08), .clear],
                           startPoint: .leading, endPoint: .trailing)
        }
    }

    private var tint: Color {
        switch state.mode {
        case .held: return Theme.miss
        case .problem: return Theme.danger
        case .imported, .done: return Theme.done
        case .upgraded: return Theme.edition
        case .downloading, .steps:
            return state.rows.first.flatMap { PosterTint.color(mediaItemId: $0.mediaItemId) } ?? Theme.grab
        }
    }
}

/// The average colour of a saved poster, lifted so a dark poster still gives
/// a visible tint. Cached per title for the extension's lifetime.
enum PosterTint {
    private static var cache: [Int: Color] = [:]

    static func color(mediaItemId: Int) -> Color? {
        if let hit = cache[mediaItemId] { return hit }
        guard let data = DownloadsActivityAttributes.ContentState.posterData(mediaItemId: mediaItemId),
              let image = UIImage(data: data)?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let lifted = Color(hue: Double(h), saturation: Double(min(1, s * 1.35)), brightness: Double(max(0.6, b)))
        cache[mediaItemId] = lifted
        return lifted
    }
}
