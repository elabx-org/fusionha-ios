import SwiftUI
import UIKit
import FusionhaKit

/// One History event in its day's card (mock browse-title.js `evRow`): the
/// status glyph on the day's spine, the event and its monochrome version
/// chip, the time, then the failure's reason, the release on one line, its
/// chips (quality, score, group, source) and, on a failure, Regrab and
/// Blocklist. A grab keeps both in its context menu.
struct V2HistoryEventRow: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var inkOverride
    let detail: ItemDetail
    let item: V2HistoryItem
    /// The day's last row: the spine stops at its glyph.
    var last = false
    @State private var width: CGFloat = 0

    private var entry: HistoryEntry { item.entry }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var regrab: HistoryEntry? { V2HistoryEvent.regrabEntry(entry, in: detail.history ?? []) }
    private var canGrab: Bool { model.me?.can("grab") ?? true }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            glyph
            VStack(alignment: .leading, spacing: 4) {
                head
                lines
                if V2HistoryEvent.isFailure(entry) { actions.padding(.top, 6) }
            }
            .padding(.bottom, last ? 0 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contextMenu { menu }
    }

    /// A DELETED event left unfolded is the old file going (mock `EVC.DELETED`):
    /// a dim glyph, never the failure red.
    private var isReplaced: Bool { entry.eventType == "DELETED" }

    private var glyph: some View {
        let badge: BadgeInk = inkOverride ?? .page
        let look = isReplaced ? (icon: "trash", fill: badge.secondary, onFill: badge.knockout)
            : V2EpisodeHistoryStrip.look(entry.eventType, ink: badge)
        return ZStack(alignment: .top) {
            if !last {
                Rectangle()
                    .fill(ink.opacity(0.16))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 26)
            }
            Image(systemName: look.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(look.onFill)
                .frame(width: 24, height: 24)
                .background(look.fill, in: Circle())
        }
        .frame(width: 24)
        .accessibilityHidden(true)
    }

    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(isReplaced && entry.editionId != nil ? "File replaced" : eventStyle(entry.eventType).label)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
            if let edition = item.edition {
                EditionBadge(tier: edition.tier, state: V2HistoryEvent.badgeState(entry), showsCount: false)
                if !edition.versionKey.isEmpty {
                    Text(edition.versionKey).font(.system(size: 12, weight: .medium)).foregroundStyle(muted).lineLimit(1)
                }
            }
            if let trigger = triggerLabel(entry.grabTrigger) {
                V2ReleaseCard.filledTag(Text(trigger), color: muted).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(item.time)
                .font(.system(size: 12.5))
                .monospacedDigit()
                .foregroundStyle(muted)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var lines: some View {
        if let reason = V2HistoryEvent.reason(entry) {
            Text(reason)
                .font(.system(size: 12.5))
                .foregroundStyle(entry.held != nil ? Theme.stuck : Theme.danger)
                .lineLimit(2)
        }
        if let title = entry.sourceTitle, !title.isEmpty {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(ink.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(title)
        }
        if let replaced = item.replaced {
            Text("Replaced \(replaced)")
                .font(.system(size: 12))
                .foregroundStyle(muted)
                .lineLimit(1)
        }
        chips
    }

    @ViewBuilder
    private var chips: some View {
        let extra = V2HistoryItem.releaseChips(entry)
        if entry.quality != nil || entry.cfScore != nil || !extra.isEmpty {
            // At most two group/source chips, one under 330 pt (mock `evRow`);
            // the row wraps rather than squeezing the quality into an ellipsis.
            FlowRow(spacing: 5, lineSpacing: 4) {
                if let quality = entry.quality {
                    V2ReleaseCard.filledTag(Text(DetailText.quality(quality)), color: ink)
                }
                if let score = entry.cfScore, score != 0 {
                    V2ReleaseCard.filledTag(Text(V2HistoryEvent.score(score)),
                                            color: score < 0 ? Theme.danger : Theme.doneText)
                }
                ForEach(Array(extra.prefix(width > 0 && width < 330 ? 1 : 2)), id: \.self) { label in
                    V2ReleaseCard.filledTag(Text(label), color: ink.opacity(0.85))
                }
            }
            .lineLimit(1)
            .padding(.top, 2)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if canGrab, let regrab {
                Button("Regrab", systemImage: "arrow.clockwise") { Task { await store.regrab(regrab) } }
                    .foregroundStyle(ink)
            }
            if entry.blocklistTarget != nil {
                Button("Blocklist", systemImage: "nosign", role: .destructive) { Task { await store.blocklist(entry) } }
                    .foregroundStyle(Theme.danger)
            }
        }
        .font(.system(size: 13.5, weight: .semibold))
        .buttonStyle(.glass)
        .controlSize(.small)
        .v2FadesUnderTitleBar()
    }

    @ViewBuilder
    private var menu: some View {
        if canGrab, let regrab, !V2HistoryEvent.isFailure(entry) {
            Button("Regrab", systemImage: "arrow.clockwise") { Task { await store.regrab(regrab) } }
        }
        if entry.blocklistTarget != nil, !V2HistoryEvent.isFailure(entry) {
            Button("Blocklist", systemImage: "nosign", role: .destructive) { Task { await store.blocklist(entry) } }
        }
        if let title = entry.sourceTitle, !title.isEmpty {
            Button("Copy release name", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = title
                store.show("Release name copied", variant: .success)
            }
        }
        V2BlockGroupButton(group: entry.chips?.first { $0.kind == "group" }?.label)
    }
}
