import SwiftUI
import FusionhaKit

/// The facts a collapsed group card shows (fusionha's queue redesign): the
/// version label, "N downloads · total", the states summary, the episode
/// strip and the group's Manual Import action. Only group facts: each
/// download's own chips, source and rail stay on its row.
struct QueueGroupSummary {
    let group: QueueLogic.Group

    private var downloads: [QueueItem] { group.downloads }

    /// `Extended · HD`, or the tier; a pair names both tiers (`4K + HD`).
    var versionLabel: String {
        if group.isPair {
            return Set(downloads.map(\.tier)).sorted { $0 == .uhd && $1 == .hd }.map(\.word).joined(separator: " + ")
        }
        let lead = downloads[0]
        return VersionLabel.text(tier: lead.tier, edition: lead.edition,
                                 multipleEditions: lead.hasMultipleEditions == true) ?? lead.tier.word
    }

    /// "4 downloads · 4.7 GB total".
    var countLine: String {
        let noun = group.isPair ? "versions" : "downloads"
        let size = downloads.reduce(0) { $0 + max(0, $1.size) }
        return "\(downloads.count) \(noun) · \(ActFmt.bytes(size)) total"
    }

    struct StatePart: Hashable {
        let text: String
        let failure: Bool
    }

    /// The states summary, failures first (`group-model.ts`): "1 failed · 3 held".
    var states: [StatePart] {
        func mode(_ i: QueueItem) -> String {
            if i.outcome == "failed" || (i.phaseTerminal == true && i.phase != nil && i.phase != "complete") { return "failed" }
            if i.lane == .retrying { return "retrying" }
            switch i.cockpitState {
            case .stuck: return "stuck"
            case .held: return "held"
            case .awaiting: return "waiting"
            case .stalled: return "stalled"
            case .importing: return "importing"
            case .queued: return "queued"
            case .downloading: return i.isPhaseMode ? "in progress" : "downloading"
            }
        }
        let order = ["failed", "stuck", "held", "retrying", "waiting", "stalled", "downloading", "in progress", "importing", "queued"]
        let counts = Dictionary(grouping: downloads, by: mode).mapValues(\.count)
        return order.compactMap { m in
            counts[m].map { StatePart(text: "\($0) \(m)", failure: m == "failed" || m == "stuck") }
        }
    }

    /// "S06E04 · S06E05 · S06E17", at most 8 then "+N"; a pack's "S02" stays; nil for movies.
    var episodeStrip: String? {
        let codes = downloads.compactMap { $0.episodeLabel?.components(separatedBy: " · ").first?
            .trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !codes.isEmpty else { return nil }
        let more = codes.count - 8
        return codes.prefix(8).joined(separator: " · ") + (more > 0 ? " · +\(more)" : "")
    }

    var heldIds: [Int] { downloads.filter { $0.cockpitState == .held }.map(\.id) }

    /// "Review all 4 in Manual Import", or "Review 2 held…" when only some are held.
    var reviewLabel: String? {
        let held = heldIds.count
        guard held > 0 else { return nil }
        return held == downloads.count ? "Review all \(held) in Manual Import" : "Review \(held) held in Manual Import"
    }
}

/// Which group cards are open, for this run of the app (the web keeps it per
/// session). Collapsed is the default.
@MainActor
enum QueueGroupMemory {
    static var open: Set<String> = []

    static func set(_ id: String, open isOpen: Bool) {
        if isOpen { open.insert(id) } else { open.remove(id) }
    }
}

/// The group header's text block.
struct QueueGroupHeaderText: View {
    let summary: QueueGroupSummary
    let open: Bool
    let openTitle: () -> Void
    let review: () -> Void

    var body: some View {
        let lead = summary.group.downloads[0]
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(lead.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    .onTapGesture(perform: openTitle)
                    .accessibilityAddTraits(.isButton)
                Text(summary.versionLabel).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(lead.tier.color).lineLimit(1).fixedSize()
            }
            Text(summary.countLine).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Theme.dim)
            statesLine
            if !open, let strip = summary.episodeStrip {
                Text(strip).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if let label = summary.reviewLabel {
                Button(label, systemImage: "arrow.right", action: review)
                    .buttonStyle(ActButtonStyle(kind: .primary))
                    .padding(.top, 4)
            }
        }
    }

    private var statesLine: some View {
        summary.states.enumerated().reduce(Text("")) { line, entry in
            let part = Text(entry.element.text).foregroundColor(entry.element.failure ? Theme.danger : Theme.mut)
                .fontWeight(entry.element.failure ? .semibold : .regular)
            return entry.offset == 0 ? part : line + Text(" · ").foregroundColor(Theme.dim) + part
        }
        .font(.system(size: 12.5))
    }
}
