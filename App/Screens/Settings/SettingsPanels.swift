import SwiftUI

/// Routes a Settings panel slug (the web's `/settings/<slug>`) to its page.
/// Native panels get a `case`; everything else opens the web panel in an
/// in-app web view, signed in with the stored session cookie.
@ViewBuilder
func settingsPanel(_ slug: String) -> some View {
    switch slug {
    default:
        SettingsWebPanel(slug: slug)
    }
}
