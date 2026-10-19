import SwiftUI
import FusionhaKit

enum BlocklistCategory: String, CaseIterable {
    case recoverable, manual, permanent

    init(reason: String?) {
        let text = (reason ?? "").lowercased()
        if text.isEmpty { self = .permanent; return }
        if text.contains("manual") || text.contains("removed from queue") { self = .manual; return }
        if ["removed by download client", "no longer in queue", "stalled", "vanished", "dead"].contains(where: text.contains) {
            self = .recoverable
            return
        }
        self = .permanent
    }

    var label: String {
        switch self {
        case .recoverable: return "Dead NZB"
        case .manual: return "Manual"
        case .permanent: return "Bad content"
        }
    }

    var color: Color {
        switch self {
        case .recoverable: return Theme.miss
        case .manual: return Theme.dim
        case .permanent: return Theme.danger
        }
    }

    /// The reason's wash: a status tone (manual is a neutral `dim`, no pattern).
    var tone: StatusTone {
        switch self {
        case .recoverable: return StatusTone(.miss)
        case .manual: return StatusTone(color: Theme.dim)
        case .permanent: return StatusTone(.danger)
        }
    }

    var icon: String {
        switch self {
        case .recoverable: return "arrow.clockwise"
        case .manual: return "hand.raised"
        case .permanent: return "exclamationmark.octagon"
        }
    }

    /// The row's primary action.
    var primary: (icon: String, label: String) {
        switch self {
        case .recoverable: return ("arrow.clockwise", "Un-blocklist & re-search")
        case .manual: return ("checkmark", "Un-blocklist")
        case .permanent: return ("trash", "Un-blocklist anyway")
        }
    }
}
