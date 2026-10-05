import AppIntents
import WidgetKit
import FusionhaKit

/// The paged widget's dots: shows `page` on the widgets of `family`
/// (`medium` / `large`). Runs from `Button(intent:)`; WidgetKit then reloads
/// the timeline, which reads the page back from `WidgetPageStore`.
struct SetWidgetPageIntent: AppIntent {
    static let title: LocalizedStringResource = "Show widget view"
    static let description = IntentDescription("Switches the fusionha widget to its next view.")
    static let isDiscoverable = false

    @Parameter(title: "Widget size") var family: String
    @Parameter(title: "View") var page: String

    init() {}

    init(family: String, page: WidgetPage) {
        self.family = family
        self.page = page.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let page = WidgetPage(rawValue: page) {
            WidgetPageStore.setPage(page, family: family)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "Downloads")
        return .result()
    }
}
