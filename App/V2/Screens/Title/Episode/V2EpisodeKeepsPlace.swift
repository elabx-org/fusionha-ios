import SwiftUI
import FusionhaKit

extension View {
    /// The episode page's scroll view keeps its place across a fold
    /// (`V2PagePlace`): the tab and version shown, and the offset measured
    /// past the header (the hero folded, the short header beside the season
    /// list open), put back the first time this page appears. Nil keeps nothing.
    func v2EpisodeKeepsPlace(_ place: V2PagePlace?, header: Binding<CGFloat>, tab: Binding<EpisodeSheetTab>,
                             versionId: Binding<Int?>) -> some View {
        modifier(V2EpisodeKeepsPlace(place: place, header: header, tab: tab, versionId: versionId))
    }
}

private struct V2EpisodeKeepsPlace: ViewModifier {
    let place: V2PagePlace?
    @Binding var header: CGFloat
    @Binding var tab: EpisodeSheetTab
    @Binding var versionId: Int?
    @State private var host = UUID()
    @State private var started = false
    /// Reports count once the kept offset is back (the new host's first
    /// frames at the top would overwrite it).
    @State private var armed = false
    @State private var position = ScrollPosition(edge: .top)

    private var mine: V2PagePlace? {
        guard let place, place.owner == host else { return nil }
        return place
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, y in
                guard armed, let place = mine else { return }
                place.headerOffset = FoldHeaderOffset.place(offset: Double(y), header: Double(header))
            }
            .onChange(of: tab) { _, new in mine?.episodeTab = new }
            .onChange(of: versionId) { _, new in mine?.versionId = new }
            .onAppear { start() }
    }

    /// Once per page instance (Back onto it in the same host doesn't jump).
    private func start() {
        guard !started else { return }
        started = true
        guard let place else {
            armed = true
            return
        }
        let kept = place.headerOffset
        if let keptTab = place.episodeTab { tab = keptTab }
        if let keptVersion = place.versionId { versionId = keptVersion }
        place.owner = host
        Task { @MainActor in
            if let kept {
                // Once the new host has laid out its header and tab.
                try? await Task.sleep(for: .milliseconds(150))
                let y = kept.offset(header: Double(header))
                if y > 1 { position.scrollTo(y: CGFloat(y)) }
                try? await Task.sleep(for: .milliseconds(80))
            }
            armed = true
        }
    }
}
