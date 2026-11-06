import SwiftUI

/// The open held decision's choice and scroll, kept by the queue
/// (`V2QueueView`, which a fold never replaces) so closing the Duo
/// mid-decision shows the same decision in its sheet with the same option
/// picked and the same scroll, and opening it brings the page back the
/// same way (fold continuity, owner 2026-11-06). One decision at a time:
/// another download starts fresh.
@MainActor
final class HeldDecisionDraft {
    private(set) var itemId: Int?
    private var choiceValue: HeldChoice = .stay
    private var scrollY: CGFloat = 0

    init() {
        #if DEBUG
        // CI fold shots: `FUSIONHA_SCREENSHOT_HELD_CHOICE=removeSearch` and
        // `FUSIONHA_SCREENSHOT_HELD_SCROLL=<pt>` preset the focused download's decision.
        let env = ProcessInfo.processInfo.environment
        if let id = env["FUSIONHA_SCREENSHOT_QUEUE_SCROLL"].flatMap(Int.init) {
            itemId = id
            choiceValue = env["FUSIONHA_SCREENSHOT_HELD_CHOICE"].flatMap(HeldChoice.init(rawValue:)) ?? .stay
            scrollY = env["FUSIONHA_SCREENSHOT_HELD_SCROLL"].flatMap(Double.init).map { CGFloat($0) } ?? 0
        }
        #endif
    }

    /// The kept choice for `id` (Stays held for a new one).
    func choice(for id: Int) -> HeldChoice { itemId == id ? choiceValue : .stay }

    func setChoice(_ choice: HeldChoice, for id: Int) {
        take(id)
        choiceValue = choice
    }

    func offset(for id: Int) -> CGFloat { itemId == id ? scrollY : 0 }

    func setOffset(_ y: CGFloat, for id: Int) {
        take(id)
        scrollY = y
    }

    private func take(_ id: Int) {
        guard itemId != id else { return }
        itemId = id
        choiceValue = .stay
        scrollY = 0
    }
}
