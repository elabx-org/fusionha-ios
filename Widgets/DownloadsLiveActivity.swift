import ActivityKit
import SwiftUI
import WidgetKit
import FusionhaKit

/// The Downloads Live Activity (approved "Live Activity redesign"): the Lock
/// Screen and StandBy views, the Dynamic Island, and the Apple Watch Smart
/// Stack (`.small`). Every state comes from `ContentState.mode`.
struct DownloadsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadsActivityAttributes.self) { context in
            let _ = LiveActivityThumbs.use(context.state)
            LiveActivityRoot(state: context.state, stale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(LiveActivityLinks.tap(context.state))
        } dynamicIsland: { context in
            let state = context.state
            LiveActivityThumbs.use(state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityIslandLeading(state: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityIslandTrailing(state: state)
                }
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityIslandCenter(state: state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityIslandBottom(state: state)
                }
            } compactLeading: {
                LiveActivityCompactLeading(state: state)
            } compactTrailing: {
                LiveActivityCompactTrailing(state: state)
            } minimal: {
                LiveActivityMinimal(state: state)
            }
            .widgetURL(LiveActivityLinks.tap(state))
            .keylineTint(LiveActivityTone.of(state))
        }
        .supplementalActivityFamilies([.small])
    }
}

/// Picks the Watch / small layout or the full Lock Screen one.
private struct LiveActivityRoot: View {
    let state: DownloadsActivityAttributes.ContentState
    let stale: Bool
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small:
            LiveActivitySmall(state: state)
                .padding(10)
        default:
            LiveActivityLockScreen(state: state, stale: stale)
                .padding(16)
                .background { LiveActivityWash(state: state) }
                .overlay(alignment: .bottomTrailing) {
                    // fusionha's downloads are paused (Activity › Pause).
                    if state.paused == true {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.14), in: Capsule())
                            .padding(10)
                    }
                }
        }
    }
}

/// Where a tap goes, by state.
enum LiveActivityLinks {
    static func tap(_ state: DownloadsActivityAttributes.ContentState) -> URL? {
        switch state.mode {
        case .imported, .upgraded:
            if let id = state.event?.mediaItemId { return URL(string: "fusionha://item/\(id)") }
        case .problem:
            if let id = state.event?.downloadId { return URL(string: "fusionha://activity?focus=\(id)") }
        default:
            break
        }
        return URL(string: "fusionha://activity")
    }

    /// Opens the native Manual Import sheet on these held downloads.
    static func review(_ ids: [Int]) -> URL? {
        URL(string: "fusionha://activity?rescue=" + ids.map(String.init).joined(separator: ","))
    }
}

enum LiveActivityTone {
    static func of(_ state: DownloadsActivityAttributes.ContentState) -> Color {
        switch state.mode {
        case .problem: return Theme.danger
        case .held: return Theme.miss
        case .imported, .done: return Theme.done
        case .upgraded: return Theme.edition
        case .downloading, .steps: return Theme.grab
        }
    }

    /// The state's status token (its pattern under Monochrome).
    static func token(_ state: DownloadsActivityAttributes.ContentState) -> MonoToken {
        switch state.mode {
        case .problem: return .danger
        case .held: return .miss
        case .imported, .done: return .done
        case .upgraded: return .edition
        case .downloading, .steps: return .grab
        }
    }

    /// HD purple, 4K cyan, as everywhere else; Monochrome's two tier-chip greys.
    static func version(_ label: String) -> Color {
        Theme.tierFill(tier(label))
    }

    /// The version's tier token: 4K wears grab's pattern, HD edition's.
    static func versionToken(_ label: String) -> MonoToken { tier(label).monoToken }

    private static func tier(_ label: String) -> QualityTier { label.contains("4K") ? .uhd : .hd }

    /// The version without the default edition: "Standard · HD" → "HD".
    static func shortVersion(_ label: String) -> String {
        label.replacingOccurrences(of: "Standard · ", with: "").trimmingCharacters(in: .whitespaces)
    }
}

enum LiveActivityFormat {
    static func rate(_ bps: Double?) -> String? {
        guard let bps, bps > 0 else { return nil }
        let mb = bps / 1_000_000
        return mb >= 10 ? "\(Int(mb.rounded())) MB/s" : String(format: "%.1f MB/s", mb)
    }

    static func eta(_ seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        if seconds < 60 { return "<1m" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func percent(_ fraction: Double?) -> String? {
        fraction.map { "\(Int(($0 * 100).rounded()))%" }
    }

    /// "64" for the display-face hero (the % is set smaller beside it).
    static func percentNumber(_ fraction: Double?) -> String? {
        fraction.map { "\(Int(($0 * 100).rounded()))" }
    }

    /// "41.6" + "MB/s" for the several-downloads hero.
    static func rateParts(_ bps: Double?) -> (number: String, unit: String)? {
        guard let text = rate(bps), let space = text.lastIndex(of: " ") else { return nil }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }
}
