import ActivityKit
import SwiftUI
import WidgetKit

struct DownloadsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadsActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.35))
                .widgetURL(URL(string: "fusionha://activity"))
        } dynamicIsland: { context in
            let state = context.state
            let tint = state.stuck ? Theme.stuck : (state.finished ? Theme.done : Theme.grab)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(state.activeCount)", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(tint)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.overallFraction, format: .percent.precision(.fractionLength(0)))
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(state.topTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer()
                            Text(state.topTierLabel).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        ProgressView(value: state.overallFraction).tint(tint)
                    }
                }
            } compactLeading: {
                Image(systemName: state.finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(tint)
            } compactTrailing: {
                ProgressView(value: state.overallFraction)
                    .progressViewStyle(.circular)
                    .tint(tint)
            } minimal: {
                ProgressView(value: state.overallFraction)
                    .progressViewStyle(.circular)
                    .tint(tint)
            }
            .widgetURL(URL(string: "fusionha://activity"))
        }
    }
}

private struct LockScreenView: View {
    let state: DownloadsActivityAttributes.ContentState

    var body: some View {
        let tint = state.stuck ? Theme.stuck : (state.finished ? Theme.done : Theme.grab)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: state.finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(tint)
                Text(state.finished ? "Imported" : "\(state.activeCount) downloading")
                    .font(.headline)
                Spacer()
                Text(state.overallFraction, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
            }
            HStack {
                Text(state.topTitle).font(.subheadline).lineLimit(1)
                Spacer()
                Text(state.topTierLabel).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            ProgressView(value: state.overallFraction).tint(tint)
        }
    }
}
