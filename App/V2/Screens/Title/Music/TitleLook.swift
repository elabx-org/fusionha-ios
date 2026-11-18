import SwiftUI

/// The title page's look while the poster-led page is on trial (owner
/// 2026-11-10, mock "Title page, Apple style"): Account › This iPhone has
/// the switch, off by default, so today's page stays until the owner picks
/// the new one. Kept on the device, like the other This iPhone settings.
enum TitleLook {
    /// On unless turned off in Account › This iPhone (default since
    /// 2026-11-18, the owner's plan; was a trial switch).
    static let posterKey = "v2.titlePage.posterLook"
}
