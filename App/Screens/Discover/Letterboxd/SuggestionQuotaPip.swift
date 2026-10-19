import SwiftUI
import FusionhaKit

/// The rail's weekly-limit pip (web `QuotaPip`, from `/requests/quota`): a
/// ring of what's left and "3 of 5 left this week", or "Unlimited requests".
struct SuggestionQuotaPip: View {
    let quota: RequestQuota

    var body: some View {
        let pip = SuggestionRail.pip(quota)
        HStack(spacing: 7) {
            if let fraction = pip.fraction { ring(fraction) }
            (Text(pip.strong).foregroundColor(pip.low ? Theme.miss : Theme.txt) + Text(pip.rest))
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .foregroundStyle(pip.low ? Theme.miss : Theme.mut)
        .padding(.leading, pip.fraction == nil ? 11 : 8)
        .padding(.trailing, 11)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(Theme.panel2)
            if pip.low { Capsule().fill(Theme.miss.opacity(0.12)) }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityHint(pip.help)
    }

    private func ring(_ fraction: Double) -> some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.i2, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(1.2)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
