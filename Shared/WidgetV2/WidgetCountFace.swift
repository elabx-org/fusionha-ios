import SwiftUI
import WidgetKit

/// The v2 small widgets' face (mock `.small-w`): a symbol and the widget's
/// name on top, one big count at the foot, and a two-line description under
/// it. `tint` colours the header (orange only for what needs the owner).
struct WidgetCountFace: View {
    let symbol: String
    let title: String
    let count: Int
    let detail: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetCountHeader(symbol: symbol, title: title, tint: tint)
            Spacer(minLength: 4)
            Text("\(count)")
                .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                .tracking(-1.3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// `pause.circle.fill  Needs you`: 13pt bold, in the face's tint.
struct WidgetCountHeader: View {
    let symbol: String
    let title: String
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
            Text(title).font(.system(size: 13, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(tint)
        .widgetAccentable()
    }
}
