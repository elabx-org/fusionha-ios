import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next: the next airings and releases under day headings, with HD/4K chips.
struct WidgetUpNextPage: View {
    let rows: [UpNextRow]
    let large: Bool

    var body: some View {
        if rows.isEmpty {
            WidgetEmptyText("Nothing airing soon")
        } else {
            WidgetUpNextDayList(rows: Array(rows.prefix(large ? 6 : 2)), posterHeight: large ? 36 : 30)
        }
    }
}
