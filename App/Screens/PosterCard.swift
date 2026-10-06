import SwiftUI
import FusionhaKit

// MARK: - Poster card (PosterCard.tsx)

/// Clean art with small solid corner badges (monitor, 4K, attention, live
/// download state, kebab), then title, meta and the coverage rails. In select
/// mode a checkbox replaces the monitor badge and a tap toggles selection.
struct PosterCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.openPosterSheet) private var openSheet
    let item: MediaItem
    @State private var pressing = false
    @State private var longPresses = 0

    private var monitored: Bool { item.monitored ?? true }
    private var selecting: Bool { model.selectMode }
    private var selected: Bool { model.selection.contains(item.id) }

    /// A fresh grab wins the corner over a calm upgrade.
    private var liveState: RailState? {
        let states = item.editions.map { $0.chipState(isSeries: item.kind == .series) }
        if states.contains(.downloading) { return .downloading }
        if states.contains(.upgrading) { return .upgrading }
        return nil
    }

    /// ⚠ amber (not found) unless every flagged edition is a pure dead link.
    private var attention: (deadLink: Bool, color: Color)? {
        guard item.hasAttention == true else { return nil }
        let flagged = item.editions.filter { $0.attention == true }
        let allDead = !flagged.isEmpty && flagged.allSatisfy {
            ($0.deadLinkCount ?? 0) > 0 && $0.deadLinkCount == $0.unresolvedFileCount
        }
        return (allDead, allDead ? Theme.stuck : Theme.miss)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
                // Press-and-hold feedback: the poster sinks and dims while held.
                // A black wash, not `.brightness`: the art is a UIKit-backed view.
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.black.opacity(pressing ? 0.14 : 0))
                        .allowsHitTesting(false)
                }
                .scaleEffect(pressing ? 0.95 : 1)
                .animation(motion ? .easeOut(duration: 0.18) : nil, value: pressing)
            // Plex-app rhythm on phones: title/year 14.5 / 12.5, regular weight.
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(monitored ? Theme.txt : Theme.mut)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if let year = item.year {
                        Text(String(year)).lineLimit(1)
                        Text("·")
                    }
                    KindGlyph(kind: item.kind)
                    if item.isAnime == true { AnimeChip().fixedSize().layoutPriority(1) }
                }
                .font(.system(size: 12.5))
                .foregroundStyle(monitored ? Theme.mut : Theme.dim)
                CoverageRails(item: item)
                    .padding(.top, 7)
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
        .accessibilityAddTraits(selecting && selected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: "Actions") {
            if !selecting { openSheet?(item) }
        }
    }

    private var ringColor: Color {
        if selecting && selected { return Theme.i1 }
        return attention?.color.opacity(0.7) ?? Theme.line
    }

    private var art: some View {
        PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w500"))
            .aspectRatio(2 / 3, contentMode: .fit)
            .saturation(monitored ? 1 : 0.75)
            .colorMultiply(monitored ? .white : Color(white: 0.82))
            .opacity(monitored ? 1 : 0.82)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(ringColor, lineWidth: selecting && selected ? 2 : 1))
            .shadow(color: .black.opacity(0.55), radius: 10, y: 10)
            .overlay(alignment: .topLeading) { topLeading.padding(8) }
            .overlay(alignment: .topTrailing) {
                if item.editions.contains(where: { $0.tier == .uhd }) {
                    Text("4K")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.22)))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    if let attention {
                        Image(systemName: attention.deadLink ? "link" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(attention.color)
                            .shadow(color: .black.opacity(0.85), radius: 1, y: 1)
                            .frame(width: 22, height: 22)
                            .pulseOpacity()
                            .accessibilityLabel(attention.deadLink ? "Dead link" : "Files not found")
                    }
                    if let liveState { dlBadge(liveState) }
                }
                .padding(8)
            }
            .overlay(alignment: .bottom) {
                if let setup = model.setupProgress.activeSetup(for: item.id) {
                    SetupIndicators(fraction: setup.progressFraction)
                }
            }
    }

    @ViewBuilder
    private var topLeading: some View {
        if selecting {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Theme.i1 : Color.black.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Theme.i1 : .white.opacity(0.6), lineWidth: 1.5))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 22, height: 22)
                .animation(motion ? Motion.press : nil, value: selected)
        } else {
            Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(monitored ? Theme.i2 : .white.opacity(0.72))
                .frame(width: 22, height: 22)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.18)))
                .accessibilityLabel(monitored ? "Monitored" : "Unmonitored")
        }
    }

    private func dlBadge(_ state: RailState) -> some View {
        let color = state == .upgrading ? Theme.edition : Theme.grab
        return Group {
            if state == .upgrading {
                Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold))
            } else {
                // A plain rotation, not `.symbolEffect(.rotate)`: the symbol effect
                // redrew the glyph on the main thread every frame, on or off screen.
                RepeatForever(animation: .linear(duration: 1).repeatForever(autoreverses: false)) { on in
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(motion && on ? 360 : 0))
                }
            }
        }
        .foregroundStyle(color)
        .frame(width: 22, height: 22)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.55)))
        .accessibilityLabel(state == .upgrading ? "Upgrading" : "Downloading")
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
