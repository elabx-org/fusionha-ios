import SwiftUI
import FusionhaKit

/// One version's bar on the v2 Live Activity.
struct V2LiveActivityBars {
    typealias State = DownloadsActivityAttributes.ContentState

    struct Bar: Hashable {
        let id: String
        let tier: QualityTier
        /// 0–1; nil while it waits for bytes.
        let fraction: Double?
        let held: Bool
    }

    /// The lead title's downloads (HD first), then its held versions, at most two.
    static func of(_ state: State, lead: State.Row) -> [Bar] {
        var bars = state.rows.filter { $0.mediaItemId == lead.mediaItemId }.map {
            Bar(id: "d\($0.downloadId)", tier: tier($0.version), fraction: $0.fraction, held: false)
        }
        for held in state.held where held.mediaItemId == lead.mediaItemId {
            let t = tier(held.version ?? "")
            if !bars.contains(where: { $0.tier == t }) {
                bars.append(Bar(id: "h\(held.downloadIds.first ?? 0)", tier: t, fraction: 1, held: true))
            }
        }
        return Array(bars.sorted { $0.tier == .hd && $1.tier != .hd }.prefix(2))
    }

    /// `4K`, `Extended · 4K` → 4K; anything else is HD.
    static func tier(_ version: String) -> QualityTier {
        version.contains("4K") || version.contains("2160") ? .uhd : .hd
    }
}

/// `[HD] ━━━━━━──── 62%`: the ticket (an outline while it downloads, orange
/// with "!" when held), a 5pt one-ink track, the figure.
struct V2LiveActivityBar: View {
    let bar: V2LiveActivityBars.Bar
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .onArt
        HStack(spacing: 7) {
            EditionBadge(tier: bar.tier, state: bar.held ? .held : .missing)
                .frame(minWidth: 30, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.track)
                    Capsule().fill(bar.held ? ink.held : ink.accent)
                        .frame(width: geo.size.width * min(1, max(0, bar.fraction ?? 0)))
                }
            }
            .frame(height: 5)
            Text(figure)
                .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                .foregroundStyle(bar.held ? ink.held : .white)
                .frame(minWidth: 38, alignment: .trailing)
        }
    }

    private var figure: String {
        if bar.held { return "Held" }
        guard let f = bar.fraction, f > 0 else { return "Queued" }
        return "\(Int((f * 100).rounded()))%"
    }
}
