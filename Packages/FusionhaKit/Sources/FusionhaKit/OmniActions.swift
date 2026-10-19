import Foundation

/// The omni search's row logic (web `components/omni/OmniSearchOverlay.tsx`
/// and `lib/provider-labels.ts`): the provider credit and which trailing
/// actions a row carries.
public enum OmniActions {
    /// One trailing action on an omni row.
    public enum Action: String, Sendable, Equatable {
        case open, add, request
    }

    /// What the row body does when tapped.
    public enum Primary: Sendable, Equatable {
        case open, preview, request, none
    }

    /// `providerShortLabel`: the short wordmark for a provider id, `TMDB` for
    /// anything unknown or missing.
    public static func providerShortLabel(_ provider: String?) -> String {
        switch provider ?? "tmdb" {
        case "tvdb": return "TheTVDB"
        case "tvmaze": return "TVmaze"
        case "hybrid": return "TMDB + TheTVDB"
        default: return "TMDB"
        }
    }

    /// `rowActions` for an add-lane result: Open when it's already owned,
    /// otherwise Add (with `add`) and Request (with `request`), each gated on
    /// its own capability, so a user with both sees two buttons.
    public static func addRowActions(openable: Bool, canAdd: Bool, canRequest: Bool) -> [Action] {
        if openable { return [.open] }
        var actions: [Action] = []
        if canAdd { actions.append(.add) }
        if canRequest { actions.append(.request) }
        return actions
    }

    /// `activate` for an add-lane result: open, else the preview (add), else
    /// the request modal.
    public static func addRowPrimary(openable: Bool, canAdd: Bool, canRequest: Bool) -> Primary {
        if openable { return .open }
        if canAdd { return .preview }
        if canRequest { return .request }
        return .none
    }
}
