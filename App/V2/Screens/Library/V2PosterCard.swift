import SwiftUI
import FusionhaKit

/// A v2 Library poster (mock browse-lib.js `lpost`): clean 2:3 art with a
/// hairline and a soft shadow, nothing on it, and the caption under it
/// (`V2PosterCaption`). Attention draws an orange ring, the title open on
/// the right page the accent ring. Select mode puts a checkbox in the
/// art's bottom-right corner and a tap toggles; otherwise a tap opens the
/// title (v2's title page, through `TitlePageHost`) and press-and-hold opens the poster
/// sheet. Content, not glass.
struct V2PosterCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.openPosterSheet) private var openSheet
    @Environment(\.spread) private var spread
    let item: MediaItem
    /// The card's width when the grid knows it.
    var artWidth: CGFloat?
    var showsMeta = true
    @State private var pressing = false
    @State private var pressDelay: Task<Void, Never>?
    @State private var longPresses = 0

    private var monitored: Bool { item.monitored ?? true }
    private var selecting: Bool { model.selectMode }
    private var flags: CardFlag { model.cardFlags.slot(for: item.id) }
    private var selected: Bool { flags.selected }
    private var picked: Bool { spread.isActive && !selecting && flags.picked }
    private var artSize: CGSize? { artWidth.map { CGSize(width: $0, height: $0 * 3 / 2) } }

    var body: some View {
        let _ = PerfCount.hit("V2PosterCard.body")
        let _ = PerfCount.printsChanges ? Self._printChanges() : ()
        VStack(alignment: .leading, spacing: 0) {
            art
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(pressing ? 0.14 : 0))
                        .allowsHitTesting(false)
                }
                .scaleEffect(pressing ? 0.95 : 1)
                .animation(motion ? .easeOut(duration: 0.18) : nil, value: pressing)
            V2PosterCaption(item: item, showsMeta: showsMeta)
                .padding(.top, 7)
                .padding(.horizontal, 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) {
            guard !selecting, let openSheet else { return }
            longPresses += 1
            openSheet(item)
        } onPressingChanged: { pressChanged($0) }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.selection, trigger: longPresses)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits((selecting && selected) || picked ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: "Actions") {
            if !selecting, let openSheet { openSheet(item) }
        }
    }

    private func tapped() {
        if selecting {
            if selected { model.selection.remove(item.id) } else { model.selection.insert(item.id) }
        } else {
            model.open(item.id)
        }
    }

    /// The poster sinks only once a touch has stayed put (as v1's card).
    private func pressChanged(_ down: Bool) {
        pressDelay?.cancel()
        pressDelay = nil
        guard down, !selecting, openSheet != nil else {
            if pressing { pressing = false }
            return
        }
        pressDelay = Task {
            try? await Task.sleep(for: .milliseconds(120))
            if !Task.isCancelled { pressing = true }
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
