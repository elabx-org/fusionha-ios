import SwiftUI

/// Storage as an iPhone-Storage style stacked bar with a legend (mock
/// rails.js B6, badges-mono.js): shades of one ink, the legend names them.
/// The bar is the whole capacity; what's left over is the track.
struct StorageCapsule: View {
    struct Segment: Identifiable {
        let label: String
        let bytes: Double
        /// The ink's strength: 0.86 for the first tier, 0.52 for the second,
        /// 0.35 for "Other" (the mock's shades).
        let shade: Double
        var id: String { label }
    }

    let segments: [Segment]
    /// The disk's capacity in bytes.
    let capacity: Double
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 10
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        VStack(alignment: .leading, spacing: 9) {
            bar(ink)
            PreviewFlow(spacing: 12, rowSpacing: 6) {
                ForEach(segments) { seg in
                    HStack(spacing: 5) {
                        Circle().fill(colour(seg, ink)).frame(width: 8, height: 8)
                        Text(seg.label).foregroundStyle(ink.secondary)
                        Text(Format.bytes(seg.bytes)).fontWeight(.semibold).foregroundStyle(ink.label)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func bar(_ ink: BadgeInk) -> some View {
        Canvas { ctx, size in
            let capsule = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            // The track: the label colour at 10% (a step under a rail's 15%).
            ctx.fill(capsule, with: .color(ink.track.opacity(10.0 / 15)))
            ctx.clip(to: capsule)
            let total = max(capacity, segments.reduce(0) { $0 + max(0, $1.bytes) }, 1)
            var x: CGFloat = 0
            for seg in segments where seg.bytes > 0 {
                let w = size.width * seg.bytes / total
                // A 1.5pt knockout between segments.
                let rect = CGRect(x: x, y: 0, width: max(0, w - 1.5), height: size.height)
                ctx.fill(Path(rect), with: .color(colour(seg, ink)))
                x += w
            }
        }
        .frame(height: barHeight)
        .accessibilityHidden(true)
    }

    private func colour(_ seg: Segment, _ ink: BadgeInk) -> Color {
        // `fill` is the label colour at 86%: scale from there.
        ink.fill.opacity(min(1, seg.shade / 0.86))
    }
}
