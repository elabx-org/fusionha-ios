import SwiftUI
import FusionhaKit

// The queue card's shared lines (web mock v4: CardMeta, ReleaseFacts,
// SourceGroup, CardActions), used by the single card and the rows inside a
// group card alike.

/// "HD · 1.8 GB · grabbed 22h ago · RSS": tier, pack, size, files, age, provenance.
struct QueueCardMeta: View {
    let item: QueueItem
    var showTier = true
    /// A genuine byte transfer is tagged "Full download".
    var fullDownload = false

    var body: some View {
        ActFlow(spacing: 0, lineSpacing: 4) {
            let parts = words
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 { dot }
                part.text
            }
            if let trigger = item.grabTrigger, ActProvenance.meta(trigger) != nil {
                dot
                ActProvenance(trigger: trigger)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(Theme.line))
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.mut)
    }

    private struct Part { let text: Text }

    private var words: [Part] {
        var out: [Part] = []
        if showTier {
            out.append(Part(text: Text(QueueCardText.versionLabel(item)).fontWeight(.bold).foregroundColor(item.tier.color)))
        }
        if item.packRanges != nil || item.hasPackDecisions { out.append(Part(text: Text("Pack"))) }
        if fullDownload { out.append(Part(text: Text("Full download").foregroundColor(Theme.grab))) }
        if item.size > 0 { out.append(Part(text: Text(ActFmt.bytes(item.size)))) }
        if let files = item.fileCount { out.append(Part(text: Text("\(files) files"))) }
        out.append(Part(text: Text(QueueCardText.grabbedAgo(item.ageSeconds))))
        return out
    }

    private var dot: some View { Text("  ·  ").foregroundStyle(Theme.dim) }
}

/// The release facts as chips: dashed tag = from the name, pulse = probed,
/// amber = name and file disagree. A tap shows where each value came from.
struct QueueFactChips: View {
    let item: QueueItem

    var body: some View {
        let facts = CapabilityChips.queueFacts(item)
        if !facts.isEmpty {
            ActFlow(spacing: 6, lineSpacing: 6) {
                ForEach(facts) { QueueCapabilityChip(fact: $0) }
            }
        }
    }
}

struct QueueCapabilityChip: View {
    let fact: ReleaseFactChip
    @State private var showing = false

    private var tint: Color {
        if fact.model.hasDiff { return Theme.miss }
        return fact.model.base == .probed ? Theme.done : Theme.mut
    }

    private var glyph: String {
        if fact.model.hasDiff { return "exclamationmark.triangle" }
        switch fact.model.base {
        case .probed: return "waveform.path.ecg"
        case .named: return "tag"
        default: return "clock"
        }
    }

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 5) {
                Image(systemName: glyph).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
                segments
            }
            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
            .foregroundStyle(fact.model.hasDiff ? Theme.miss : Theme.txt.opacity(0.88))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fact.model.hasDiff ? Theme.miss.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(fact.model.base == .named && !fact.model.hasDiff ? Theme.dim.opacity(0.55) : (fact.model.hasDiff ? Theme.miss.opacity(0.35) : Theme.line),
                                  style: StrokeStyle(lineWidth: 1, dash: fact.model.base == .named && !fact.model.hasDiff ? [3, 2.5] : []))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fact.label): \(fact.model.text)")
        .accessibilityHint(fact.model.tooltip)
        .popover(isPresented: $showing) {
            Text(fact.model.tooltip)
                .font(.footnote)
                .foregroundStyle(Theme.txt)
                .padding(14)
                .frame(maxWidth: 300)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var segments: some View {
        fact.model.segments.enumerated().reduce(Text("")) { line, entry in
            let s = entry.element
            var part: Text
            if let from = s.from {
                part = Text(from).strikethrough().foregroundColor(Theme.miss.opacity(0.7)) + Text("→") + Text(s.text)
            } else {
                part = Text(s.text)
            }
            if s.kind == .state { part = part.foregroundColor(Theme.dim) }
            return entry.offset == 0 ? part : line + Text(" · ").foregroundColor(Theme.dim) + part
        }
    }
}

/// Protocol · indexer · downloader, each with a glyph; wraps, never cut.
struct QueueSourceLine: View {
    let item: QueueItem

    var body: some View {
        let torrent = QueueCardText.isTorrent(item)
        let indexer = item.indexer.map(QueueCardText.splitIndexer)
        ActFlow(spacing: 16, lineSpacing: 4) {
            if let proto = item.protocolLabel {
                entry(torrent ? "link" : "newspaper", proto + (item.stages?.route == "debrid" && item.stages?.isPhaseMode == true ? " · debrid" : ""),
                      label: "Protocol")
            }
            if let indexer {
                entry("dot.radiowaves.up.forward", indexer.name, label: "Indexer", hint: indexer.via)
            }
            entry("tray.and.arrow.down", item.downloadClient ?? "Unknown client", label: "Downloader")
        }
        .font(.system(size: 14))
        .foregroundStyle(Theme.txt)
    }

    private func entry(_ icon: String, _ text: String, label: String, hint: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.mut)
            Text(text).lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(text)")
        .accessibilityHint(hint ?? "")
    }
}

/// The card's secondary actions (web `CardActions`, 0.4.198): three fixed
/// round icon slots, re-grab, remove (red), ⋯, so every card's primary button
/// is the same width. Without a grab record the re-grab slot stays empty.
struct QueueCardActions: View {
    let item: QueueItem
    let actions: QueueRowActions
    var broken = false

    var body: some View {
        HStack(spacing: 0) {
            if let regrab = actions.regrab {
                QueueIconSlot(icon: "arrow.clockwise", label: "Re-grab this release", action: regrab)
            } else {
                Color.clear.frame(width: QueueIconSlot.width, height: 44).accessibilityHidden(true)
            }
            QueueIconSlot(icon: "trash", label: "Remove from queue", tint: Theme.danger) {
                actions.remove(broken || item.cockpitState == .held)
            }
            ActMoreMenu {
                Button("Interactive search", systemImage: "person", action: actions.interactive)
                if broken {
                    Button("Blocklist & search", systemImage: "nosign") { actions.blocklist(true) }
                } else {
                    Button("Blocklist without removing", systemImage: "nosign") { actions.blocklist(false) }
                }
                Button("Copy release name", systemImage: "doc.on.doc", action: actions.copy)
            }
            .frame(width: QueueIconSlot.width, height: 44)
        }
    }
}

/// One round icon action in a card's action row: a fixed 40pt slot, 44pt tall.
struct QueueIconSlot: View {
    static let width: CGFloat = 40
    let icon: String
    let label: String
    var tint: Color = Theme.mut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: Self.width, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}
