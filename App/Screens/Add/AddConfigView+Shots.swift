import SwiftUI
import FusionhaKit

extension AddConfigView {
    #if DEBUG
    /// CI screenshots: `…_ADD_SCROLL=versions|monitor` scrolls to a section,
    /// `…_ADD_4K` turns the 4K version on and runs its check, `…_ADD_SPLIT`
    /// picks "Different for 4K", `…_ADD_GRAB=<stop>` picks a grab stop,
    /// `…_ADD_COMMIT` adds the title (what follows an add).
    func screenshotHooks(_ proxy: ScrollViewProxy) {
        let env = ProcessInfo.processInfo.environment
        if env["FUSIONHA_SCREENSHOT_ADD_4K"] != nil || env["FUSIONHA_SCREENSHOT_ADD_SPLIT"] != nil {
            flow.setTierOn(.uhd, true)
            if env["FUSIONHA_SCREENSHOT_ADD_4K"] != nil { Task { await flow.checkFourK() } }
        }
        if env["FUSIONHA_SCREENSHOT_ADD_SPLIT"] != nil {
            splitChosen = true
            flow.setTierMonitor(.uhd, "future")
        }
        if let stop = env["FUSIONHA_SCREENSHOT_ADD_GRAB"] { flow.setMinAvail(stop) }
        if env["FUSIONHA_SCREENSHOT_ADD_COMMIT"] != nil {
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await add()
            }
        }
        if let target = env["FUSIONHA_SCREENSHOT_ADD_SCROLL"] {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }
    #endif
}
