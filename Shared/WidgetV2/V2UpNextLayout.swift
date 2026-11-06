import SwiftUI
import WidgetKit
import FusionhaKit

/// v2's Up next medium and large (mock Browse › Widgets): large is "Airing
/// tonight", the next airing as a feature over the four after it; medium is
/// "This week", three rows. Small stays the one-title view. The widget's
/// kind (`UpNext`) is v1's, so a widget placed by v1 keeps working when v2
/// takes its place; only its look changes.
struct V2UpNextLayout: View {
    let entry: UpNextEntry
    let family: WidgetFamily

    /// Built into v2 only.
    static var isOn: Bool {
        #if V2
        true
        #else
        false
        #endif
    }

    /// How many rows a family fetches in v2 (nil: v1's own).
    static func limit(_ family: WidgetFamily) -> Int? {
        guard isOn else { return nil }
        switch family {
        case .systemLarge: return 5
        case .systemMedium: return 3
        default: return nil
        }
    }

    /// Large's feature poster is bigger, so it loads the w154 copy; medium's
    /// rows are small, so w92.
    static func posterSize(_ family: WidgetFamily) -> String? {
        guard isOn else { return nil }
        switch family {
        case .systemLarge: return "w154"
        case .systemMedium: return "w92"
        default: return nil
        }
    }

    var body: some View {
        if family == .systemLarge, let first = entry.rows.first {
            VStack(alignment: .leading, spacing: 8) {
                V2UpNextFeature(row: first)
                V2UpNextList(rows: Array(entry.rows.dropFirst().prefix(4)))
                Spacer(minLength: 0)
            }
        } else {
            V2UpNextList(rows: Array(entry.rows.prefix(3)), poster: CGSize(width: 22, height: 33))
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}
