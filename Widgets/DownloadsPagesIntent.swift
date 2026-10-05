import AppIntents
import WidgetKit
import FusionhaKit

/// Edit Widget for Downloads: one toggle per view, all on by default.
struct DownloadsPagesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Downloads views"
    static let description = IntentDescription("Choose the views the widget flicks through when you tap its dots.")

    @Parameter(title: "Downloading (when active)", default: true) var downloading: Bool
    @Parameter(title: "Up next", default: true) var upNext: Bool
    @Parameter(title: "Recently added", default: true) var recent: Bool
    @Parameter(title: "Library", default: true) var library: Bool
    @Parameter(title: "Indexers", default: true) var indexers: Bool
    @Parameter(title: "Wanted", default: true) var wanted: Bool
    @Parameter(title: "Requests & issues", default: true) var requests: Bool

    init() {}

    var enabled: Set<WidgetPage> {
        let flags: [(WidgetPage, Bool)] = [
            (.downloading, downloading), (.upNext, upNext), (.recent, recent), (.library, library),
            (.indexers, indexers), (.wanted, wanted), (.requests, requests),
        ]
        return Set(flags.filter { $0.1 }.map { $0.0 })
    }
}
