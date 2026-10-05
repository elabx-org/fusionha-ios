import SwiftUI

/// A tiny bar sparkline (an indexer's daily activity), scaled to its own peak.
struct WidgetSparkBars: View {
    let values: [Int]
    let color: Color

    var body: some View {
        let peak = CGFloat(max(values.max() ?? 0, 1))
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(Array(values.suffix(14).enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color.opacity(value > 0 ? 0.85 : 0.25))
                        .frame(height: max(1.5, geo.size.height * CGFloat(value) / peak))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
