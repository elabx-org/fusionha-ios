import SwiftUI
import FusionhaKit

/// `S04E16` in the episode's bar: mono, muted.
struct EpisodeCodeLabel: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
    }
}

/// The episode's own heading: its title (wrapping), then `Aired 14 Feb 2013
/// · 11 min`. The series name is the page beside it, so it isn't repeated.
struct EpisodeHeading: View {
    let episode: Episode

    private var subtitle: String {
        var parts: [String] = []
        if let instant = episode.airInstant {
            parts.append("\(episode.hasAired() ? "Aired" : "Airs") \(instant.formatted(date: .abbreviated, time: .omitted))")
        }
        if let runtime = episode.runtime, runtime > 0 { parts.append("\(runtime) min") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.title ?? "Episode \(episode.episodeNumber)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Auto search as the episode sheet's bar item, with its title and symbol
/// (the column's rule). The result arrives as the title's toast.
struct EpisodeAutoSearchItem: View {
    @Environment(DetailStore.self) private var store
    let label: String
    let code: String
    let editionId: Int?
    let episodeId: Int
    @State private var running = false

    var body: some View {
        Button {
            running = true
            Task {
                await store.search(label: label, editionId: editionId, episodeId: episodeId)
                running = false
            }
        } label: {
            Label("Auto search", systemImage: "magnifyingglass")
                .labelStyle(.titleAndIcon)
        }
        .disabled(running)
        .accessibilityLabel("Auto search \(code)")
    }
}

extension View {
    /// `duoColumnPullSource()` only when `enabled`: the episode's scroll
    /// closes it by pulling down only while it is the open Duo's right page
    /// (as a sheet or cover it has its own pull).
    func pullClosesPage(_ enabled: Bool) -> some View {
        modifier(OptionalColumnPull(enabled: enabled))
    }
}

private struct OptionalColumnPull: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.duoColumnPullSource()
        } else {
            content
        }
    }
}
