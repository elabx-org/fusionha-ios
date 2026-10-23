import SwiftUI
import FusionhaKit

/// "Pause or remove" (web `ManageSection`): Pause / Resume, or a note when
/// someone else paused it (an admin, or the Plex watchlist a list follows);
/// Remove asks first. Pausing or removing never cancels a request.
struct SourceManageSection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let view: AutoSourceView
    let enabled: Bool
    let onRemoved: () -> Void
    @State private var asking = false
    @State private var busy = false

    /// On and not paused by the person: Pause. Paused by them: Resume. Off: Resume turns it on.
    private var running: Bool { enabled && !view.source.paused }

    private var lockedNote: String? {
        guard view.source.pausedByOthers else { return nil }
        return view.kind == .plexList ? SourceDetailCopy.pausedWithWatchlist : SourceDetailCopy.pausedByAdmin
    }

    var body: some View {
        let removal = WatchlistsStore.removal(view)
        Section {
            if let lockedNote {
                row(lockedNote, desc: SourceDetailCopy.resumeDesc) { EmptyView() }
            } else {
                row(SourceDetailCopy.pause, desc: running ? SourceDetailCopy.pauseDesc : SourceDetailCopy.resumeDesc) {
                    Button(running ? SourceDetailCopy.pause : SourceDetailCopy.resume,
                           systemImage: running ? "pause.fill" : "play.fill") { togglePause() }
                        .buttonStyle(.bordered)
                        .disabled(busy)
                }
            }
            if removal.allowed {
                row(SourceDetailCopy.removeLabel, desc: SourceDetailCopy.removeDesc, danger: true) {
                    Button(SourceDetailCopy.remove, systemImage: "trash", role: .destructive) { asking = true }
                        .buttonStyle(.bordered)
                        .disabled(busy)
                }
                .confirmationDialog(SourceDetailCopy.removeAsk(view.name), isPresented: $asking, titleVisibility: .visible) {
                    Button(SourceDetailCopy.remove, role: .destructive) { remove() }
                    Button(SourceDetailCopy.keep, role: .cancel) {}
                } message: {
                    Text(removal.disconnects ? SourceDetailCopy.disconnectNote : SourceDetailCopy.removeRest)
                }
            }
        } header: {
            Text(SourceDetailCopy.manage)
        } footer: {
            Text(SourceDetailCopy.neverCancels)
        }
        .listRowBackground(AccountStyle.cell)
    }

    private func row<Trailing: View>(_ title: String, desc: String, danger: Bool = false,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(danger ? Theme.dangerText : Theme.txt)
                Text(desc).font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func togglePause() {
        busy = true
        Task {
            await store.togglePause(view, enabled: enabled, model)
            busy = false
        }
    }

    private func remove() {
        busy = true
        Task {
            let done = await store.remove(view, model)
            busy = false
            if done { onRemoved() }
        }
    }
}
