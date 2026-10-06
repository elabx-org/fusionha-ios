import AppIntents
import WidgetKit

/// A single-view widget's retry: reloads that widget's timeline.
struct ReloadWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Reload widget"
    static let description = IntentDescription("Reloads a fusionha widget.")
    static let isDiscoverable = false

    @Parameter(title: "Widget") var kind: String

    init() {}

    init(kind: String) {
        self.kind = kind
    }

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        return .result()
    }
}
