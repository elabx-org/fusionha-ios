import SwiftUI
import FusionhaKit

/// A warning line in the state's colour (web `Attention`).
struct WatchlistAttention: View {
    let lead: String
    let rest: String
    var color: Color = Theme.stuck

    var body: some View {
        Label {
            (Text(lead).bold() + Text(" " + rest)).font(.footnote).foregroundStyle(Theme.txt)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
        }
    }
}

/// An info line (web `.info`): an icon and a sentence with a bold lead.
struct WatchlistInfo: View {
    var icon = "info.circle"
    let lead: String
    let rest: String

    var body: some View {
        Label {
            (Text(lead).bold() + Text(" " + rest)).font(.footnote).foregroundStyle(Theme.mut)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.dim)
        }
    }
}
