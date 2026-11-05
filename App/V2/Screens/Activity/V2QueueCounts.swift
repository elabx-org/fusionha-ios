import Foundation
import FusionhaKit

/// The queue's counts for the caption (plan S8: "total · N need you · N
/// downloading · N importing") and the pipeline strip, from the loaded rows
/// sorted into v1's sections (`QueueSection.of`).
struct V2QueueCounts: Equatable {
    var total = 0
    var needYou = 0
    var held = 0
    var downloading = 0
    var importing = 0
    var failed = 0

    init(items: [QueueItem], total: Int) {
        self.total = total
        for item in items {
            switch QueueSection.of(item) {
            case .needs:
                needYou += 1
                if item.cockpitState == .held { held += 1 }
            case .importing: importing += 1
            case .progress, .downloading: downloading += 1
            case .failed: failed += 1
            case .upnext: break
            }
        }
    }

    /// The caption's pieces, in order; zero counts are left out after the total.
    var captionParts: [(text: String, tone: Tone)] {
        var parts: [(text: String, tone: Tone)] = [(text: "\(total) in the queue", tone: .lead)]
        if needYou > 0 { parts.append((text: "\(needYou) \(needYou == 1 ? "needs" : "need") you", tone: .needsYou)) }
        if downloading > 0 { parts.append((text: "\(downloading) downloading", tone: .active)) }
        if importing > 0 { parts.append((text: "\(importing) importing", tone: .plain)) }
        return parts
    }

    enum Tone { case lead, needsYou, active, plain }

    /// The caption read as one sentence.
    var spoken: String { captionParts.map(\.text).joined(separator: ", ") }
}
