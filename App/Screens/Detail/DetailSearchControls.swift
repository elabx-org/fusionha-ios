import SwiftUI
import FusionhaKit

// The search controls the Versions panel and the tabs share: the search button
// with its result states (SearchActionButton), the split caret's mode menu
// (SearchModeMenu), interactive search (`person`), and the flash strips.

/// SearchActionButton: idle → searching → ok / none / fail, then back to idle.
/// With a `title` it is the labelled phone button ("Search all", "Search").
struct SearchActionButton: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    /// The scope named by the flash strip and the toast.
    let label: String
    var editionId: Int?
    var season: Int?
    var episodeId: Int?
    var accessibility: String?
    var size: CGFloat = 30
    var glyph: CGFloat = 15
    var bordered = false
    /// A visible label beside the glyph (the labelled variant).
    var title: String?
    /// The labelled variant draws its own panel; off inside a split that frames it.
    var framed = true

    private enum Phase { case idle, searching, ok, none, fail }
    @State private var phase: Phase = .idle
    @State private var shakes = 0
    @State private var popped = false

    var body: some View {
        Button(action: run) {
            HStack(spacing: 7) {
                icon
                    .font(.system(size: glyph))
                    .scaleEffect(popped ? 1.2 : 1)
                    .frame(width: title == nil ? size : nil, height: title == nil ? size : nil)
                if let title {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                }
            }
            .frame(maxWidth: title == nil ? nil : .infinity)
            .frame(height: title == nil ? nil : 44)
            .background {
                if bordered || (title != nil && framed) {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.panel2)
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .disabled(phase == .searching)
        .detailShake(trigger: shakes)
        .sensoryFeedback(.success, trigger: popped) { _, new in new }
        .accessibilityLabel(accessibility ?? "Search \(label)")
    }

    @ViewBuilder private var icon: some View {
        switch phase {
        case .idle:
            Image(systemName: "magnifyingglass").foregroundStyle(title == nil ? Theme.mut : Theme.txt)
        case .searching:
            DetailSpinner(size: glyph, color: Theme.grab)
        case .ok:
            Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Theme.done)
        case .none:
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.miss)
        case .fail:
            Image(systemName: "xmark").fontWeight(.bold).foregroundStyle(Theme.danger)
        }
    }

    private func run() {
        phase = .searching
        Task {
            let decisions = await store.search(label: label, editionId: editionId, season: season, episodeId: episodeId)
            if let decisions {
                if decisions.contains(where: \.grabbed) {
                    phase = .ok
                    if !reduce {
                        withAnimation(DetailMotion.pop) { popped = true }
                        try? await Task.sleep(for: .seconds(0.16))
                        withAnimation(DetailMotion.pop) { popped = false }
                    }
                } else {
                    phase = .none
                    shakes += 1
                }
            } else {
                phase = .fail
                shakes += 1
            }
            try? await Task.sleep(for: .seconds(2.2))
            phase = .idle
        }
    }
}

/// The split caret's SearchModeMenu for one version (VersionsPanel `searchModesFor`).
struct SearchModeMenu: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    var width: CGFloat = 20
    var height: CGFloat = 30

    var body: some View {
        let name = detail.versionName(edition)
        let scope = "\(detail.title) — \(name)"
        let interval = store.seasonInterval
        Menu {
            Button {
                Task { await store.search(label: scope, editionId: edition.id) }
            } label: {
                Label {
                    Text("Search \(name)")
                    Text(detail.isSeries
                         ? "Every monitored season of this version — pack-preferred, missing + upgrades."
                         : "This version — missing + upgrades.")
                } icon: { Image(systemName: "square.stack.3d.up") }
            }
            if detail.isSeries {
                Button {
                    Task { await store.gradualSearch(label: "\(scope) · missing only", editionId: edition.id, missingOnly: true) }
                } label: {
                    Label {
                        Text("Search missing only · gradual")
                        Text("One at a time (~\(interval)s apart) in the background, across every monitored season — just this version’s missing episodes.")
                    } icon: { Image(systemName: "circle.dashed") }
                }
                Button {
                    Task { await store.gradualSearch(label: scope, editionId: edition.id, missingOnly: false) }
                } label: {
                    Label {
                        Text("Search each episode · gradual")
                        Text("The same background process — this version’s missing episodes plus any below the cutoff. One at a time, ~\(interval)s apart.")
                    } icon: { Image(systemName: "stairs") }
                }
            } else {
                Button {
                    Task { await store.search(label: "\(scope) · missing only", editionId: edition.id, missingOnly: true) }
                } label: {
                    Label {
                        Text("Search missing only")
                        Text("Only if this version has no file yet — no upgrade re-checks.")
                    } icon: { Image(systemName: "circle.dashed") }
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.cyan)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Search options — \(name)")
    }
}

/// Interactive search (`person`): a movie opens it directly; a series picks a
/// season pack or an episode first (ChooseReleaseControl → SeasonEpisodePicker).
struct InteractiveSearchButton<Face: View>: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition
    @ViewBuilder var face: Face

    var body: some View {
        let name = detail.versionName(edition)
        if detail.isSeries {
            Menu {
                Section("Interactive search · \(edition.tier.chipLabel) — pick a scope") {
                    ForEach(detail.seasonsNewestFirst) { season in
                        Button {
                            store.interactive = InteractiveTarget(editionIds: [edition.id], seasonNumber: season.seasonNumber,
                                                                  subtitle: "S\(season.seasonNumber) · Season pack")
                        } label: {
                            Label {
                                Text(season.title)
                                Text("\(season.episodes.count) eps · pack")
                            } icon: { Image(systemName: "folder") }
                        }
                    }
                }
                Menu {
                    ForEach(detail.seasonsNewestFirst) { season in
                        Menu(season.title) {
                            ForEach(season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                                Button {
                                    store.interactive = InteractiveTarget(
                                        editionIds: [edition.id], episodeId: episode.id,
                                        subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                                } label: {
                                    Text("S\(season.seasonNumber)·E\(episode.episodeNumber)")
                                    Text(episode.title ?? "TBA")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Pick an episode…", systemImage: "list.bullet")
                }
            } label: {
                face
            }
            .accessibilityLabel("Choose a release — \(name)")
        } else {
            Button {
                store.interactive = InteractiveTarget(editionIds: [edition.id], subtitle: edition.label)
            } label: {
                face
            }
            .buttonStyle(DetailPressStyle())
            .accessibilityLabel("Choose a release — \(name)")
        }
    }
}

// MARK: - Flash strips

/// AutoSearchFlash: "Searching indexers for …" with a sweeping gradient line,
/// then the grabbed / nothing-new outcome; lingers 5s.
struct AutoSearchFlashStrip: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    @State private var sweep: CGFloat = 0

    var body: some View {
        Group {
            if let flash = store.flash {
                HStack(spacing: 13) {
                    switch flash.phase {
                    case .searching:
                        DetailSpinner(size: 17, color: Theme.grab, period: 0.7)
                        (Text("Searching indexers for ") + Text(flash.scope).foregroundColor(Theme.grab).fontWeight(.bold) + Text(" …"))
                    case .done:
                        if flash.grabbed > 0 {
                            Image(systemName: "checkmark.circle").foregroundStyle(Theme.done)
                            (Text("Grabbed \(flash.grabbed) for \(flash.scope)").foregroundColor(Theme.done).fontWeight(.semibold)
                                + Text(flash.score.map { " (+\($0))" } ?? "").foregroundColor(Theme.grab))
                        } else {
                            (Text("Searched \(flash.scope)") + Text(" — no new releases").foregroundColor(Theme.mut))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.panel2)
                .overlay(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        Theme.fusion
                            .frame(width: geo.size.width * sweep, height: 2)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.grab.mix(0.4, Theme.panel2)))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .offset(y: -6)))
                .onChange(of: flash.phase, initial: true) { _, phase in
                    let searching = phase == .searching
                    if reduce { sweep = searching ? 0.9 : 1; return }
                    if searching { sweep = 0 }
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: searching ? 2.2 : 0.3)) {
                        sweep = searching ? 0.9 : 1
                    }
                }
            }
        }
        .detailAnimation(.easeInOut(duration: 0.25), value: store.flash)
    }
}

/// The gradual-search progress strip with a Stop button (SeasonGradualProgress).
struct GradualProgressStrip: View {
    @Environment(DetailStore.self) private var store

    var body: some View {
        if let job = store.gradual {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    DetailSpinner(size: 14, color: Theme.grab)
                    Text("Searching \(job.label) one at a time · \(job.current)/\(job.total)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Spacer(minLength: 0)
                    Button(job.stopping ? "Stopping…" : "Stop") { Task { await store.stopGradual() } }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .buttonStyle(.plain)
                        .disabled(job.stopping)
                }
                DetailCoverageBar(total: max(job.total, 1), owned: job.current, color: Theme.grab, height: 4)
            }
            .padding(12)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
            .padding(.top, 12)
        }
    }
}
