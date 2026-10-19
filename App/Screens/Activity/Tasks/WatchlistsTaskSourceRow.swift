import SwiftUI
import FusionhaKit

/// One source of the Watchlists & lists card (web `SourceRow`): owner · kind ·
/// label with its Checking / Error / OK pill, then its counts (a fraction
/// while it runs) and when it was last checked; a bar while running, the
/// reason and retry when it failed. State is an ambient wash, never a border.
struct WatchlistsTaskSourceRow: View {
    let source: SummarySource

    var body: some View {
        let tone = WatchlistsTaskLogic.tone(source)
        let running = tone == .running
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                (Text(source.owner).fontWeight(.semibold).foregroundColor(Theme.txt)
                 + Text(WatchlistsTaskLogic.detail(source)).foregroundColor(Theme.mut))
                    .font(.system(size: 13))
                    .lineLimit(2)
                Spacer(minLength: 4)
                pill(WatchlistsTaskLogic.stateLabel(source), color: tone.color, live: running)
            }
            WatchlistsTaskLogic.meta(source).text
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if running && source.total != nil {
                SyncBar(sync: source.sync, label: "\(source.owner) \(WatchlistsTaskLogic.kindLabel(source.kind)) progress")
                    .padding(.top, 2)
            }
            if let error = WatchlistsTaskLogic.errorLine(source) {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, color: Color, live: Bool) -> some View {
        HStack(spacing: 5) {
            SyncDot(color: color, live: live)
            Text(text)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}
