#if DEBUG
import SwiftUI

/// TEMPORARY (CI diagnosis of the launch route into All titles): a ticking
/// clock and the route's state, drawn only in the ALLTITLES screenshots.
struct V2HomeDebugReadout: View {
    @Environment(AppModel.self) private var model
    private static let start = Date()
    static let enabled = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ALLTITLES"] != nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let t = context.date.timeIntervalSince(Self.start)
            Text(String(format: "t%.1f p%d s%d o%d l%d n%d", t, model.pendingAllTitles ? 1 : 0,
                        model.allTitlesShown ? 1 : 0, model.allTitlesOnScreen ? 1 : 0,
                        model.libraryLoaded ? 1 : 0, model.library.count))
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.yellow)
                .padding(4)
                .background(.black)
        }
        .allowsHitTesting(false)
    }
}
#endif
