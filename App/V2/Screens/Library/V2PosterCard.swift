import SwiftUI
import FusionhaKit

/// A v2 Library poster (mock browse-lib.js `lpost`): clean 2:3 art with a
/// hairline and a soft shadow, nothing on it, and the caption under it
/// (`V2PosterCaption`). Attention draws an orange ring, the title open on
/// the right page the accent ring. Select mode puts a checkbox in the
/// art's bottom-right corner and a tap toggles; otherwise a tap opens the
/// title (v2's title page, through `TitlePageHost`) and press-and-hold opens the poster's
/// context menu (`V2PosterMenu`, Look Pass family 2) where the Library
/// offers one (`openPosterSheet`). Content, not glass.
struct V2PosterCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.openPosterSheet) private var openSheet
    @Environment(\.spreadActive) private var spreadActive
    let item: MediaItem
    /// The card's width when the grid knows it.
    var artWidth: CGFloat?
    var showsMeta = true
    @State private var pressDelay: Task<Void, Never>?

    private var monitored: Bool { item.monitored ?? true }
    private var selecting: Bool { model.selectMode }
    private var flags: CardFlag { model.cardFlags.slot(for: item.id) }
    private var selected: Bool { flags.selected }
    private var picked: Bool { spreadActive && !selecting && flags.picked }
    private var artSize: CGSize? { artWidth.map { CGSize(width: $0, height: $0 * 3 / 2) } }

    var body: some View {
        let _ = PerfCount.hit("V2PosterCard.body")
        VStack(alignment: .leading, spacing: 0) {
            art
            V2PosterCaption(item: item, showsMeta: showsMeta)
                .padding(.top, 7)
                .padding(.horizontal, 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        // Only tracks the press (prefetch, the menu's detail) and never
        // completes: the system context menu below owns the hold, its lift
        // and its haptic.
        .onLongPressGesture(minimumDuration: 10, maximumDistance: 10) {
        } onPressingChanged: { pressChanged($0) }
        .contextMenu {
            if openSheet != nil && !selecting { V2PosterMenu(item: item) }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits((selecting && selected) || picked ? [.isButton, .isSelected] : [.isButton])
    }

    private func tapped() {
        if selecting {
            if selected { model.selection.remove(item.id) } else { model.selection.insert(item.id) }
        } else {
            model.open(item.id)
        }
    }

    /// A press starts the title's prefetch; one that stays put also fetches
    /// what the context menu drills into.
    private func pressChanged(_ down: Bool) {
        pressDelay?.cancel()
        pressDelay = nil
        // A press is most likely a tap: start fetching what its page needs.
        if down, !selecting { V2TitlePrefetch.start(item.id, model: model) }
        guard down, !selecting, openSheet != nil else { return }
        // A press that stays put is likely a hold: fetch what the context menu drills into.
        pressDelay = Task {
            try? await Task.sleep(for: .milliseconds(120))
            if !Task.isCancelled { V2PosterMenuDetails.shared.load(item.id, client: model.client) }
        }
    }

    private var ring: (color: Color, width: CGFloat) {
        if selecting && selected { return (Theme.primary, 2.5) }
        if picked { return (Theme.primary, 2.5) }
        if item.hasAttention == true { return (Theme.stuck, 2) }
        return (Theme.txt.opacity(0.08), 0.5)
    }

    private var art: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w500"), size: artSize) }
            .modifier(V2UnmonitoredDim(active: !monitored))
            .shelfPosterPlated(radius: 12, ring: ring.color, ringWidth: ring.width, size: artSize)
            .overlay(alignment: .bottomTrailing) {
                if selecting { checkbox.padding(7) }
            }
            .overlay(alignment: .bottom) {
                if let setup = model.setupProgress.slots.slot(for: item.id).setup {
                    SetupIndicators(fraction: setup.progressFraction)
                }
            }
    }

    /// Select mode's checkbox (mock `.ck`): a white ring, the accent when on.
    private var checkbox: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .opacity(selected ? 1 : 0)
            .frame(width: 26, height: 26)
            .background(selected ? Theme.primary : Color.black.opacity(0.18), in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
            .animation(motion ? Motion.press : nil, value: selected)
            .accessibilityHidden(true)
    }
}

/// An unmonitored poster: desaturated and faded (as v1's).
private struct V2UnmonitoredDim: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.saturation(0.75).opacity(0.8)
        } else {
            content
        }
    }
}
