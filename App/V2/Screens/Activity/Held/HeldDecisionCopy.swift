import Foundation
import FusionhaKit

/// The words of a held download's row and decision panel, from what the
/// server sends today: `held` (short + text), `held_detail` and the parsed
/// release. Nothing here guesses Fusionha's pick (API gap 7, plan §3).
enum HeldDecisionCopy {
    /// "S1 E7 · NTb WEB-DL 2160p", else the movie's year and release.
    static func subtitle(_ item: QueueItem) -> String {
        var parts: [String] = []
        if let label = QueueCardText.subtitle(item) { parts.append(label) }
        let release = [item.parsed?.releaseGroup, item.parsed?.source, item.parsed?.resolution.map { "\($0)p" }]
            .compactMap { $0 }.joined(separator: " ")
        if !release.isEmpty { parts.append(release) } else if item.size > 0 { parts.append(ActFmt.bytes(item.size)) }
        return parts.joined(separator: " · ")
    }

    /// The problem in one line: the server's short words, then the score
    /// against your copy, the copy it would replace, or its sentence.
    static func problem(_ item: QueueItem) -> (lead: String, detail: String?) {
        let reason = QueueCardText.heldReason(item)
        let cf = HeldCF.compareLine(item.heldDetail?.candidateCf, item.heldDetail?.currentCf)
        let detail = cf ?? reason.guard ?? reason.text
        return (detail == nil ? reason.lead : reason.lead + ":", detail)
    }

    /// The panel's headline: the server's full sentence when it sends one.
    static func headline(_ item: QueueItem) -> String {
        if let text = item.held?.text, !text.isEmpty { return text }
        return problem(item).lead.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    /// One side of the evidence: a caption and its lines (`bad` marks the
    /// value that caused the hold, drawn in the held ink).
    struct Line {
        let text: String
        var bad = false
    }

    struct Side {
        let caption: String
        var lines: [Line]
    }

    /// This download against the copy it would join or replace.
    static func evidence(_ item: QueueItem) -> (this: Side, yours: Side)? {
        guard let d = item.heldDetail else { return nil }
        var this = Side(caption: "This download", lines: [])
        let named = [d.releaseGroup ?? item.parsed?.releaseGroup, d.claimedQuality ?? item.parsed?.quality]
            .compactMap { $0 }.joined(separator: " · ")
        if !named.isEmpty { this.lines.append(Line(text: named)) }
        if d.mislabeled == true, let probed = d.probedQuality {
            let res = d.probedResolution.map { " (\($0.w)×\($0.h))" } ?? ""
            this.lines.append(Line(text: "Measured \(probed)\(res)", bad: true))
        }
        if let hdr = d.claimedHdr, !hdr.isEmpty {
            this.lines.append(Line(text: "Named \(hdr.joined(separator: ", ")) · file \(d.probedHdr ?? "none")", bad: d.kind == "mislabeled_hdr"))
        }
        if item.size > 0 { this.lines.append(Line(text: ActFmt.bytes(item.size))) }
        if let cf = d.candidateCf { this.lines.append(Line(text: "Score \(cf)", bad: d.currentCf.map { cf <= $0 } ?? false)) }

        var yours = Side(caption: "Your \(item.tier.badgeLetters) version", lines: [])
        if let current = d.currentQuality {
            yours.lines.append(Line(text: [d.currentGroup, current].compactMap { $0 }.joined(separator: " · "), bad: false))
            if let formats = d.currentFormats, !formats.isEmpty {
                yours.lines.append(Line(text: formats.prefix(3).joined(separator: ", "), bad: false))
            }
            if let cf = d.currentCf { yours.lines.append(Line(text: "Score \(cf)")) }
        } else {
            yours.lines.append(Line(text: "No file yet", bad: false))
        }
        if let verdict = d.verdict { yours.lines.append(Line(text: "Verdict: \(HeldCopy.verdictLabel(verdict))")) }
        return (this, yours)
    }
}
