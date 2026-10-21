import SwiftUI
import FusionhaKit

// MARK: - Poster card (PosterCard.tsx)

/// A poster as a lit object on the shelf, with the web's art badges (4K flag,
/// Monitor bookmark, attention and download state; ruling R1, no text but the
/// 4K flag). Below: the title, year · kind, then one rail per version. In
/// select mode a checkbox takes the bookmark's corner and a tap toggles.
struct PosterCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.openPosterSheet) private var openSheet
    @Environment(\.spread) private var spread
    let item: MediaItem
    @State private var pressing = false
    @State private var longPresses = 0

    private var monitored: Bool { item.monitored ?? true }
    private var selecting: Bool { model.selectMode }
    private var selected: Bool { model.selection.contains(item.id) }
    /// In a Spread, the title open on the right page is outlined in the grid.
    private var picked: Bool { spread.isActive && !selecting && model.presentedItem?.id == item.id }

    /// Attention glows softly around the poster; the rail says what is wrong.
    private var attentionColor: Color? {
        guard item.hasAttention == true else { return nil }
        let flagged = item.editions.filter { $0.attention == true }
        let allDead = !flagged.isEmpty && flagged.allSatisfy {
            ($0.deadLinkCount ?? 0) > 0 && $0.deadLinkCount == $0.unresolvedFileCount
        }
        return allDead ? Theme.stuck : Theme.miss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
                // Press-and-hold feedback: the poster sinks and dims while held.
                // A black wash, not `.brightness`: the art is a UIKit-backed view.
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.black.opacity(pressing ? 0.14 : 0))
                        .allowsHitTesting(false)
                }
                .scaleEffect(pressing ? 0.95 : 1)
                .animation(motion ? .easeOut(duration: 0.18) : nil, value: pressing)
            VStack(alignment: .leading, spacing: 2) {
                // Phone rhythm (PosterCard.module.css ≤540): 14.5 medium / 12.5.
                Text(item.title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(monitored ? Theme.txt : Theme.mut)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    // The year never truncates; anime shows its chip in place of the kind glyph.
                    if let year = item.year {
                        Text(String(year)).lineLimit(1).fixedSize().layoutPriority(2)
                        Text("·")
                    }
                    if item.isAnime == true {
                        AnimeChip().fixedSize().layoutPriority(1)
                    } else {
                        KindGlyph(kind: item.kind)
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim)
                CoverageRails(item: item, spacing: 4)
                    .padding(.top, 6)
            }
            .padding(.top, 8)
            .padding(.horizontal, 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selecting {
                if selected { model.selection.remove(item.id) } else { model.selection.insert(item.id) }
            } else {
                model.open(item.id)
            }
        }
        // Press-and-hold (450ms, 10pt tolerance) opens the quick-actions sheet,
        // replacing the old ⋯ button (LibraryPosterSheet).
        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) {
            guard !selecting, let openSheet else { return }
            longPresses += 1
            openSheet(item)
        } onPressingChanged: { pressing = $0 && !selecting && openSheet != nil }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.selection, trigger: longPresses)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits((selecting && selected) || picked ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: "Actions") {
            if !selecting { openSheet?(item) }
        }
    }

    private var ringColor: Color {
        if selecting && selected { return Theme.txt }
        if picked { return Theme.primary }
        return Theme.txt.opacity(0.07)
    }

    private var ringWidth: CGFloat {
        if selecting && selected { return 2 }
        return picked ? 2.5 : 0.5
    }

    private var art: some View {
        // A 2:3 box the art fills: art that isn't 2:3 (Attack on Titan's)
        // reports its aspect-filled size, which made the card wider than its
        // column and pushed it over its neighbour (or the fold's gutter).
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w500")) }
            .saturation(monitored ? 1 : 0.75)
            .colorMultiply(monitored ? .white : Color(white: 0.82))
            .opacity(monitored ? 1 : 0.82)
            .shelfPoster(ring: ringColor, ringWidth: ringWidth)
            // Attention as a soft glow, never a coloured ring (web 0.4.222).
            .shadow(color: (attentionColor ?? .clear).opacity(0.55), radius: 7)
            .overlay { PosterArtBadges(badges: PosterBadges(item), showsMonitor: !selecting) }
            .overlay(alignment: .topLeading) {
                if selecting { checkbox.padding(8) }
            }
            .overlay(alignment: .bottom) {
                if let setup = model.setupProgress.slots.slot(for: item.id).setup {
                    SetupIndicators(fraction: setup.progressFraction)
                }
            }
    }

    /// Select mode's checkbox: a control, so glass, cream when on.
    private var checkbox: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Theme.onInk)
            .opacity(selected ? 1 : 0)
            .scaleEffect(selected ? 1 : 0.5)
            .frame(width: 24, height: 24)
            .background(selected ? Theme.txt : .clear, in: Circle())
            .glassEffect(.regular, in: Circle())
            .animation(motion ? Motion.press : nil, value: selected)
            .accessibilityHidden(true)
    }
}

/// The poster actions (PosterActionsSheet): Automatic search, Interactive
/// search (one per tier with 2+ editions), Monitor/Unmonitor, then Refresh
/// metadata, Edit… and Delete….
struct PosterActions: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        let anyMonitored = item.editions.contains(where: \.monitored)
        Section(item.title) {
            Button("Automatic search", systemImage: "magnifyingglass") { model.autoSearch(item.id) }
            if item.editions.count >= 2 {
                ForEach(item.editions) { edition in
                    Button {
                        model.interactiveSearch(item.id, tier: edition.tier)
                    } label: {
                        Label(edition.tier == .hd ? "Interactive · HD 1080p" : "Interactive · 4K UHD", systemImage: "person")
                    }
                }
            } else {
                Button("Interactive search", systemImage: "person") {
                    model.interactiveSearch(item.id, tier: item.editions.first?.tier)
                }
            }
            Button(anyMonitored ? "Unmonitor" : "Monitor", systemImage: anyMonitored ? "bookmark.slash" : "bookmark") {
                model.setMonitored(item.id, title: item.title, monitored: !anyMonitored)
            }
        }
        Section {
            Button("Refresh metadata", systemImage: "arrow.clockwise") { model.refreshMetadata(item.id, title: item.title) }
            Button("Edit…", systemImage: "pencil") { model.edit(item.id) }
            Button("Delete…", systemImage: "trash", role: .destructive) { model.confirmDelete(item.id, title: item.title) }
        }
    }
}
