import SwiftUI
import FusionhaKit

// A pushed season or episode page keeps its place across a fold, which
// builds its host again (the sheet folded, the shell's column open). The
// place lives per window (`V2TitleStacks.place`), so the new host's page
// finds it: the season keeps the episode row under the eye line (an item,
// not points: the two layouts differ in width), the episode its tab,
// version and offset past its header (`V2EpisodeKeepsPlace`). Only the page
// on screen writes (`owner`), so the leaving host can't overwrite it.

/// One pushed page's kept place.
@MainActor
final class V2PagePlace {
    /// The rows that came under the eye line (season page).
    var log = FoldAnchorLog<AnyHashable>()
    /// The page instance on screen.
    var owner: UUID?
    /// Episode page: the scroll, the tab and the version shown.
    var headerOffset: FoldHeaderOffset?
    var episodeTab: EpisodeSheetTab?
    var versionId: Int?
}

/// The eye line of the list on screen, in global coordinates, and where it
/// sits in the list (a fraction of its height) for the restore.
@MainActor
final class FoldPlaceLine {
    var y: CGFloat = 0
    var fraction: CGFloat = 0.2
}

/// What a row needs to report itself (`.foldPlaceRow`).
struct FoldPlaceRecorder {
    let place: V2PagePlace
    let host: UUID
    let line: FoldPlaceLine

    @MainActor
    func report(_ id: AnyHashable, frame: CGRect) {
        guard place.owner == host, frame.minY <= line.y, frame.maxY > line.y else { return }
        place.log.record(id, at: ProcessInfo.processInfo.systemUptime)
    }
}

extension EnvironmentValues {
    @Entry var foldPlaceRecorder: FoldPlaceRecorder?
}

extension View {
    /// A row the page may keep under the eye line across a fold. Inside a
    /// `List` the row's `ForEach` id must be `id` (the restore scrolls to it).
    func foldPlaceRow<ID: Hashable>(_ id: ID) -> some View {
        modifier(FoldPlaceRow(id: AnyHashable(id)))
    }

    /// The list (inside a `ScrollViewReader`) keeps its place in `place`:
    /// the rows report, and the first time this page appears with a kept
    /// row it scrolls that row back under the eye line. Nil keeps nothing.
    func keepsFoldPlace(_ place: V2PagePlace?, proxy: ScrollViewProxy) -> some View {
        modifier(FoldPlaceList(place: place, proxy: proxy))
    }
}

private struct FoldPlaceRow: ViewModifier {
    @Environment(\.foldPlaceRecorder) private var recorder
    let id: AnyHashable

    @ViewBuilder
    func body(content: Content) -> some View {
        if let recorder {
            // Global, not the scroll view's space: inside a List that space isn't certain.
            content.onGeometryChange(for: CGRect.self) { geo in
                geo.frame(in: .global)
            } action: { frame in
                recorder.report(id, frame: frame)
            }
        } else {
            content
        }
    }
}

private struct FoldPlaceList: ViewModifier {
    let place: V2PagePlace?
    let proxy: ScrollViewProxy
    @State private var host = UUID()
    @State private var line = FoldPlaceLine()
    @State private var started = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { geo in
                geo.frame(in: .global)
            } action: { frame in
                // Under the bars, a fifth of the way down at most (`FoldAnchor`'s line).
                let offset = min(120, frame.height * 0.2)
                line.y = frame.minY + offset
                line.fraction = frame.height > 0 ? offset / frame.height : 0.2
            }
            .environment(\.foldPlaceRecorder, place.map { FoldPlaceRecorder(place: $0, host: host, line: line) })
            .onAppear { start() }
    }

    /// Once per page instance (Back onto it in the same host doesn't jump).
    private func start() {
        guard let place, !started else { return }
        started = true
        let anchor = place.log.anchor(before: ProcessInfo.processInfo.systemUptime)
        place.owner = host
        guard let anchor, anchor != AnyHashable(FoldAnchorTop.header) else { return }
        Task { @MainActor in
            // Once the new host has laid its rows out.
            try? await Task.sleep(for: .milliseconds(120))
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { scroll(to: anchor) }
            place.log.settle(anchor, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func scroll(to anchor: AnyHashable) {
        guard let id = anchor.base as? any Hashable else { return }
        // The row's own eye-line point on the list's: the line falls inside it.
        proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: line.fraction))
    }
}
