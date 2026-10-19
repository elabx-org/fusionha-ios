import Foundation

// The Automatic requests cards' state wash (web `watchlist-copy.ts` META.wash
// and `LetterboxdCard` washColor): a status tint on the whole card, never a
// border. nil = no wash.

extension PlexWatchlistState {
    /// Active washes done, the broken states wash stuck, the rest stay plain.
    public var wash: MonoToken? {
        switch self {
        case .on: return .done
        case .needsSignIn, .tokenInvalid, .error: return .stuck
        default: return nil
        }
    }

    /// The card's wash: a pass in flight turns a washed card to grab.
    public func wash(syncing: Bool) -> MonoToken? {
        guard let base = wash else { return nil }
        return syncing ? .grab : base
    }
}

extension LetterboxdLogic {
    /// Running grabs, connected is done, an unreadable profile is stuck,
    /// not connected (or not allowed) has no wash.
    public static func wash(_ connection: Connection, running: Bool, allowed: Bool = true) -> MonoToken? {
        guard allowed else { return nil }
        switch connection {
        case .ok: return running ? .grab : .done
        case .bad: return .stuck
        case .none: return nil
        }
    }
}
