import SwiftUI
import WidgetKit

/// A count tile: a big rounded number, and a status dot with its label.
struct WidgetStatTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(WidgetStyle.numeral(22))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            WidgetDotLine(color: color, text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            WidgetFill(color: Color.white.opacity(0.06), accentedOpacity: 0.08)
                .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous))
        }
    }
}
