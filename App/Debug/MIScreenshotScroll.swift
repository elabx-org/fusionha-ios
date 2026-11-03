import SwiftUI

/// CI screenshots (DEBUG only): `FUSIONHA_SCREENSHOT_MI_OPEN=<row id>` opens
/// that Manual Import row once the scan loads, and the cards or table list
/// scrolls it to the top. Release builds read nothing and do nothing.
enum MIScreenshot {
    /// The row the screenshot asks for, or nil (always nil outside DEBUG).
    static var openRow: Int? {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_MI_OPEN"].flatMap(Int.init)
        #else
        nil
        #endif
    }

    /// The closing toast's time on screen: 4 s, or 60 s for CI screenshots
    /// (`FUSIONHA_SCREENSHOT_MI_TOAST_HOLD=1`), which can't time a 4 s toast.
    static var closingToastDuration: Double {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_MI_TOAST_HOLD"] != nil ? 60 : 4
        #else
        4
        #endif
    }

    #if DEBUG
    /// Rows that have been laid out (their `onAppear` ran): a lazy title
    /// section builds its rows late, and `scrollTo` misses a row with no frame.
    @MainActor static var laidOut: Set<Int> = []
    #endif
}

extension View {
    /// Marks a Manual Import row as laid out for `MIScreenshotScroll` (DEBUG only).
    func miScreenshotLaidOut(_ rowId: Int) -> some View {
        #if DEBUG
        onAppear { MIScreenshot.laidOut.insert(rowId) }
        #else
        self
        #endif
    }
}

/// Scrolls the row `FUSIONHA_SCREENSHOT_MI_OPEN` opened to the top (F17):
/// retries `scrollTo` until the row has a frame, then once more after the
/// open animation settles. Logs to the probe log when the scan has no such
/// row, or the row never lays out, so a wrong id shows in the CI output
/// instead of a silently wrong screenshot.
struct MIScreenshotScroll: ViewModifier {
    let openId: Int?
    let rowIds: [Int]
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: openId) { await scroll() }
        #else
        content
        #endif
    }

    #if DEBUG
    @MainActor private func scroll() async {
        guard let id = openId, MIScreenshot.openRow == id else { return }
        guard rowIds.contains(id) else {
            DeepLinkProbe.log("mi-open: no row \(id) in the scan (rows \(rowIds.map(String.init).joined(separator: ",")))")
            return
        }
        for _ in 0..<20 where !MIScreenshot.laidOut.contains(id) {
            proxy.scrollTo(id, anchor: .top)
            try? await Task.sleep(for: .milliseconds(150))
        }
        if !MIScreenshot.laidOut.contains(id) { DeepLinkProbe.log("mi-open: row \(id) never laid out") }
        try? await Task.sleep(for: .milliseconds(400))
        proxy.scrollTo(id, anchor: .top)
    }
    #endif
}
