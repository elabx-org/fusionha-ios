import Foundation
import FusionhaKit

/// One version's lane on a v2 queue card (mock activity.js `qcard` with the
/// rails rule B4): the version's T5 badge, what is happening in words, the
/// amount on the right, and a bar only where there is an amount (a real
/// transfer, or the stages done of a decypharr job). A queued version has no
/// bar, one line that says so.
struct QueueLaneModel: Equatable {
    let tier: QualityTier
    let badge: EditionBadgeState
    let label: String
    let amount: String?
    let bar: Bar
    /// "NTb · WEB-DL · DD+ 5.1 · 2.9 GB · usenet".
    let release: String?

    enum Bar: Equatable {
        case none
        /// A byte transfer, 0...1.
        case progress(Double)
        /// Stages done of those that run.
        case steps(done: Int, total: Int)
    }

    @MainActor
    init(_ item: QueueItem, telemetry: QueueTelemetry?) {
        tier = item.tier
        release = Self.release(item)
        let mode = QueueCardMode(item)
        switch mode {
        case .held:
            badge = .held
            label = QueueCardText.heldTag(item).capitalizedFirst
            amount = item.size > 0 ? ActFmt.bytes(item.size) : nil
            bar = Bar.none
        case .stuck:
            badge = .held
            label = item.warning ?? "Stuck · needs a look"
            amount = nil
            bar = Bar.none
        case .failed:
            badge = .missing
            label = item.stages?.current.map { "Failed at \(QueueRail.stageLabel($0).lowercased())" } ?? "Failed"
            amount = nil
            bar = Bar.none
        case .retrying:
            badge = .downloading(progress: nil)
            label = item.stages?.current.map { "Retrying at \(QueueRail.stageLabel($0).lowercased())" } ?? "Retrying"
            amount = nil
            bar = Bar.none
        case .importing:
            // Downloaded, and the import poll hasn't picked it up yet: the
            // same Importing section and full badge, without claiming the
            // import already runs.
            badge = .downloading(progress: 1)
            label = item.rowState == .awaitingImport ? "Downloaded · waiting to import" : "Importing into your library"
            amount = nil
            bar = Bar.none
        case .phase:
            let ring = QueueRail.ring(item.stages)
            badge = .downloading(progress: ring.map { Double($0.done) / Double(max(1, $0.total)) })
            let stage = QueueRail.stageLabel(item.stages?.current ?? item.phase).lowercased()
            label = ring.map { "Processing · \(stage), step \(min($0.done + 1, $0.total)) of \($0.total)" } ?? "Processing · \(stage)"
            amount = item.phasePercent.map { "\($0)%" }
            bar = ring.map { Bar.steps(done: $0.done, total: $0.total) } ?? Bar.none
        case .bytes:
            badge = .downloading(progress: item.fraction)
            if item.stalled {
                label = "Stalled"
            } else if let eta = telemetry?.eta {
                label = "Downloading · \(ActFmt.etaShort(eta)) left"
            } else {
                label = "Downloading"
            }
            amount = "\(item.pct)%"
            bar = .progress(item.fraction)
        case .waiting:
            badge = .downloading(progress: nil)
            label = "Waiting for the download client"
            amount = nil
            bar = Bar.none
        case .other:
            badge = .downloading(progress: nil)
            label = "Queued in \(Self.client(item.downloadClient))"
            amount = item.size > 0 ? ActFmt.bytes(item.size) : nil
            bar = Bar.none
        }
    }

    /// The release line: group, then the parsed facts, size and protocol.
    static func release(_ item: QueueItem) -> String? {
        var parts: [String] = []
        if let group = item.parsed?.releaseGroup { parts.append(group) }
        if item.parsed?.isRemux == true { parts.append("Remux") } else if let source = item.parsed?.source { parts.append(source) }
        if let audio = item.parsed?.audioLabel { parts.append(audio) }
        if item.size > 0 { parts.append(ActFmt.bytes(item.size)) }
        if let proto = item.protocolLabel { parts.append(proto.lowercased()) }
        return parts.isEmpty ? item.releaseTitle : parts.joined(separator: " · ")
    }

    /// "SABnzbd (decypharr)" reads "SABnzbd".
    static func client(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "the client" }
        return name.components(separatedBy: " (").first ?? name
    }
}
