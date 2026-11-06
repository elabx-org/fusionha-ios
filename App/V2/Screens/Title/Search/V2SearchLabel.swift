import SwiftUI
import FusionhaKit

/// An automatic-search control's label: the magnifying glass and its title
/// at rest, a spinner and "Searching…" while the run lasts, then the
/// outcome ("Grabbed", "Nothing new", "Couldn't search") for a few seconds.
/// Plays the haptics (light on tap, success, error) unless `haptics` is off
/// because another view at the same place already plays them.
struct V2SearchLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let title: String
    let activity: SearchActivity?
    var iconOnly = false
    var haptics = true
    /// The spinner's colour on a filled (prominent) button.
    var spinner: Color?

    var body: some View {
        Group {
            if iconOnly {
                icon
                    .accessibilityLabel(activity?.label ?? title)
            } else {
                Label { Text(activity?.label ?? title) } icon: { icon }
            }
        }
        .contentTransition(reduce ? .identity : .opacity)
        .animation(reduce ? nil : .easeInOut(duration: 0.2), value: activity)
        .v2SearchHaptics(haptics ? activity : nil)
    }

    @ViewBuilder
    private var icon: some View {
        if activity?.isSearching == true {
            ProgressView()
                .controlSize(.small)
                .tint(spinner)
                .accessibilityHidden(true)
        } else {
            Image(systemName: activity?.symbol ?? "magnifyingglass")
        }
    }
}

/// The in-place line a row or header shows while a search started from a
/// menu or a swipe runs (those close on tap): a small spinner and
/// "Searching…" in the accent, then the outcome in the page's ink. The
/// row it sits in plays `v2SearchHaptics` (this line only exists while
/// there is something to say, so it never sees the start).
struct V2SearchStatusLine: View {
    @Environment(\.pagePalette) private var page
    let activity: SearchActivity

    var body: some View {
        HStack(spacing: 5) {
            if activity.isSearching {
                ProgressView()
                    .controlSize(.mini)
                    .tint(Theme.accentText)
            } else {
                Image(systemName: activity.symbol)
                    .font(.system(size: 10.5, weight: .bold))
            }
            Text(activity.label)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(activity.isSearching ? Theme.accentText : (page?.ink ?? Theme.txt))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Light tap when a search starts, success when it grabbed, error when
    /// the request failed; nothing for "Nothing new".
    func v2SearchHaptics(_ activity: SearchActivity?) -> some View {
        sensoryFeedback(trigger: activity) { _, new in
            switch new {
            case .searching?: return .impact(weight: .light)
            case .grabbed?: return .success
            case .failed?: return .error
            default: return nil
            }
        }
    }
}
