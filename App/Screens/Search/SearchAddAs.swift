import SwiftUI
import FusionhaKit

/// Search's "Add as [provider] ⌄" line (Discover's `DiscoverAddAsControl`):
/// the metadata provider a series added from Search is built with, Default
/// (the Settings provider), TMDB, TVDB or Hybrid. It was the Add sheet's
/// "Added as" before Add moved into Search (owner, 2026-11-12: "we've lost
/// the option to select metadata provider during search"). One choice for
/// the session, shared with Discover.
struct SearchAddAs: View {
    static let height: CGFloat = 34

    var body: some View {
        DiscoverAddAsControl()
            .fixedSize()
            .frame(height: Self.height)
            .padding(.horizontal, Theme.pageGutter + 2)
    }

    /// For people who can add, unless only movies are searched (always TMDB).
    @MainActor static func shown(_ model: AppModel, kind: SearchKind) -> Bool {
        guard !model.requestScoped, model.me.map({ $0.hasCapability("add") }) ?? true else { return false }
        return kind != .movie
    }

    /// The Settings provider "Default" names (Discover loads it too).
    @MainActor static func loadDefault(_ model: AppModel) async {
        guard !model.requestScoped, let settings = try? await model.client?.discoverSettings() else { return }
        DiscoverSession.shared.globalProvider = settings.metadataProvider ?? "tmdb"
    }
}
