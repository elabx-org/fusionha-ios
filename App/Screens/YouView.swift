import SwiftUI
import FusionhaKit

/// The requester's "You" tab: the Account page (`AccountView`, the web's
/// `AccountContent`) under the tab's own title row, so the tab and the
/// Account sheet are one screen.
struct YouView: View {
    var body: some View {
        Screen {
            AccountView(pageTitle: "You")
        }
    }
}
