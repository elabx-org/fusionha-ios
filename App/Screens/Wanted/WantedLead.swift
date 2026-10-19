import SwiftUI
import FusionhaKit

/// The tab lead under the filter bar (`.lead`): what the tab holds, with its state dot.
struct WantedLead: View {
    let tab: WantedTab

    var body: some View {
        let dot = Text(Image(systemName: Theme.isMono ? tab.token.symbol : "circle.fill")).font(.system(size: Theme.isMono ? 9 : 6)).foregroundColor(tab.accent).baselineOffset(1.5)
        let b: (String) -> Text = { Text($0).foregroundColor(Theme.txt).bold() }
        let text: Text
        switch tab {
        case .missing:
            text = Text("Monitored versions with ") + b("no file yet") + Text(" — ") + dot + Text(" missing. Search runs the engine across every monitored version.")
        case .cutoff:
            text = Text("A file exists but sits ") + b("below the profile cutoff") + Text(" — ") + dot + Text(" an upgrade is wanted. Search looks for a release that meets cutoff.")
        case .upcoming:
            text = Text("Movies ") + b("awaiting a release") + Text(" — ") + dot + Text(" in cinemas, or announced, but not yet out on digital/physical for your profile. (Upcoming ") + Text("episodes").italic() + Text(" live on the Calendar.)")
        case .fourk:
            text = Text("Titles you already own in ") + b("HD") + Text(" for which a genuine 2160p release has been ") + b("observed") + Text(" on your indexers — ") + dot + Text(" nothing is grabbed automatically. (This is ") + b("observe-only") + Text(": it reports what has been spotted during normal searches, off by default until turned on in Settings.)")
        }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Turn on observing" (ghost, 4K-tinted).
struct ObserverButton: View {
    let action: () async -> Void
    @State private var busy = false

    var body: some View {
        Button {
            busy = true
            Task { await action(); busy = false }
        } label: {
            Text(busy ? "Turning on…" : "Turn on observing").foregroundStyle(QualityTier.uhd.color)
        }
        .buttonStyle(ActButtonStyle(kind: .ghost))
        .disabled(busy)
    }
}
