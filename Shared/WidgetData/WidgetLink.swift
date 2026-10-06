import Foundation
import FusionhaKit

/// Deep links the app's `onOpenURL` understands (built by FusionhaKit's `WidgetRoute`).
enum WidgetLink {
    static let activity = WidgetRoute.activity.url
    static let calendar = WidgetRoute.calendar.url
    static let library = WidgetRoute.library.url

    static func item(_ id: Int?) -> URL? {
        guard let id, id > 0 else { return nil }
        return WidgetRoute.item(id).url
    }

    /// Always a URL: the title, or `fallback` when the row has no id.
    static func item(_ id: Int?, fallback: WidgetRoute) -> URL {
        WidgetRoute.item(id, fallback: fallback).url
    }
}
