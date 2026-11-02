import SwiftUI
import FusionhaKit

/// "Follow a list" (web `FollowSheet` around `FollowBody`, fusionha 0.4.237):
/// the address flow (any public MDBList, Trakt or Letterboxd list), with a
/// quiet switch to follow someone's Letterboxd watchlist by username. Cancel
/// and Follow sit in the toolbar, so Follow never scrolls away: it previews
/// first, then adds exactly what was previewed.
struct FollowSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: WatchlistsStore
    @State private var byUsername = false
    @State private var feed = FeedFollowModel()
    @State private var watch = WatchlistFollowModel()

    private var uhdAllowed: Bool { store.letterboxd?.alsoUhdAllowed ?? false }
    private var busy: Bool { byUsername ? watch.reading || watch.adding : feed.reading || feed.adding }
    private var ready: Bool { byUsername ? watch.ready : feed.ready }

    var body: some View {
        NavigationStack {
            Form {
                if byUsername {
                    WatchlistFollowSections(watch: watch)
                } else {
                    FeedFollowSections(feed: feed, uhdAllowed: uhdAllowed)
                }
                Section {
                    Button(byUsername ? FeedCopy.addressInstead : FeedCopy.watchInstead) {
                        withAnimation(.smooth) { byUsername.toggle() }
                    }
                    .font(.subheadline)
                } footer: {
                    if let read = store.letterboxd {
                        Text(FollowCopy.linkedAfter(linkedAfter(read), max: read.maxLinkedLists))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(FollowCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(FollowCopy.follow, systemImage: "plus") { submit() }
                        .disabled(!ready || busy)
                }
            }
            .onChange(of: feed.url) { feed.typedChanged() }
            .onChange(of: watch.username) { watch.typedChanged() }
        }
        .presentationDragIndicator(.visible)
    }

    private func submit() {
        if byUsername {
            watch.submit(store, model) { dismiss() }
        } else {
            feed.submit(store, model, uhdAllowed: uhdAllowed) { dismiss() }
        }
    }

    private func linkedAfter(_ read: LetterboxdRead) -> Int {
        Swift.min(LetterboxdLogic.linkedCount(read, sources: store.sources) + 1, read.maxLinkedLists)
    }
}

/// The Preview button with the 30-second wait between previews.
struct FollowPreviewButton: View {
    let reading: Bool
    let ready: Bool
    let nextAt: Date?
    let run: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = nextAt.map { Swift.max(0, Int($0.timeIntervalSince(context.date).rounded(.up))) } ?? 0
            HStack {
                Button(action: run) {
                    if reading {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(FeedCopy.reading) }
                    } else {
                        Label(FeedCopy.preview, systemImage: "magnifyingglass")
                    }
                }
                .disabled(!ready || reading || left > 0)
                if left > 0 {
                    Spacer()
                    Text("You can preview again in \(left) s").font(.caption).foregroundStyle(Theme.mut)
                }
            }
        }
    }
}
