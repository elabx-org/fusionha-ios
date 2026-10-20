import Foundation

/// The approver Inbox's hardware-keyboard triage (web `useTriageKeys.ts`):
/// A approve · D decline · J/K move · Return open · X select. Pure: the app
/// supplies the key, its modifiers and whether typing or another overlay is
/// in the way.
public enum TriageKeys {
    public enum Action: Sendable, Hashable { case approve, decline, next, prev, open, toggle }

    /// Where the keys land, which decides the actions that mean something.
    public enum Surface: Sendable, Hashable {
        /// Wide: the queue beside the focused request's aside.
        case panes
        /// Phone "Select several": the checkbox list (web `stacked`).
        case list
        /// Phone cards: the top card only.
        case deck
        /// The full decision card in its Details sheet.
        case card
    }

    /// The action a key press maps to, or nil (a modifier held, a repeat, or
    /// another key). Shift is allowed: "A" approves like "a".
    public static func action(characters: String, isReturn: Bool, command: Bool = false, control: Bool = false,
                              option: Bool = false, isRepeat: Bool = false) -> Action? {
        if isRepeat || command || control || option { return nil }
        if isReturn { return .open }
        switch characters.lowercased() {
        case "a": return .approve
        case "d": return .decline
        case "j": return .next
        case "k": return .prev
        case "x": return .toggle
        case "\r", "\n": return .open
        default: return nil
        }
    }

    /// Keys act only when the Inbox has them: never while typing, and never
    /// while another sheet, dialog, popover or menu is open.
    public static func allowed(enabled: Bool, typing: Bool, overlayOpen: Bool) -> Bool {
        enabled && !typing && !overlayOpen
    }

    /// Whether an action does anything on a surface (the deck only decides
    /// and opens its top card; the card sheet has no selection).
    public static func accepts(_ action: Action, on surface: Surface) -> Bool {
        switch surface {
        case .panes, .list: return true
        case .deck: return [.approve, .decline, .open].contains(action)
        case .card: return action != .toggle
        }
    }

    /// Web L11: in the checkbox list the card isn't on screen, so A / D first
    /// open it rather than deciding a request nobody can see.
    public static func decideOpensCard(on surface: Surface) -> Bool { surface == .list }
}

/// The queue's keyboard focus (web `triage-state.ts`): held by id plus the
/// last index, so when the focused row is decided the row that slides into
/// its place takes focus.
public struct TriageQueueFocus: Sendable, Hashable {
    public var focusId: Int?
    public var lastIndex: Int

    public init(focusId: Int? = nil, lastIndex: Int = 0) {
        self.focusId = focusId
        self.lastIndex = lastIndex
    }

    public func effective(_ order: [Int]) -> Int? {
        if let focusId, order.contains(focusId) { return focusId }
        guard !order.isEmpty else { return nil }
        return order[min(lastIndex, order.count - 1)]
    }

    /// J / K: one row down or up, clamped to the ends.
    public mutating func move(_ delta: Int, in order: [Int]) {
        guard !order.isEmpty else { return }
        let at = effective(order).flatMap { order.firstIndex(of: $0) } ?? 0
        let next = max(0, min(order.count - 1, at + delta))
        focusId = order[next]
        lastIndex = next
    }

    public mutating func focus(_ id: Int, in order: [Int]) {
        guard let at = order.firstIndex(of: id) else { return }
        focusId = id
        lastIndex = at
    }
}

/// After a decision is handed up the Inbox ignores another for `window`
/// (web `DECIDE_LOCK_MS`, `triage-motion.ts`), whatever the motion setting,
/// so a double press never decides the next card too; nothing decides while
/// a card is in flight either.
public struct DecideLock: Sendable, Hashable {
    public static let window: TimeInterval = 0.35

    public private(set) var until: Date = .distantPast
    /// A deck card is flying off: its decision isn't handed up yet.
    public var inFlight = false

    public init() {}

    public func locked(at now: Date = Date()) -> Bool { inFlight || now < until }

    /// A decision was handed up: start the window.
    public mutating func handUp(at now: Date = Date()) {
        until = now.addingTimeInterval(Self.window)
    }

    /// Claims the right to decide now: false while locked, else starts the window.
    public mutating func claim(at now: Date = Date()) -> Bool {
        guard !locked(at: now) else { return false }
        handUp(at: now)
        return true
    }
}
