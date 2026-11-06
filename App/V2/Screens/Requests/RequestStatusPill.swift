import SwiftUI
import FusionhaKit

/// A request's status as a small dot-and-word pill (mock requests.js
/// `pill`): Pending in the muted ink, Approved in the accent (it is active),
/// Available in the label colour, Declined in red, Not available yet in the
/// held orange (the requester can ask again). An age can follow ("Pending · 16 d").
struct RequestStatusPill: View {
    let status: String
    var age: String = ""

    var body: some View {
        let tone = Self.tone(status)
        HStack(spacing: 5) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(tone.label + (age.isEmpty ? "" : " · \(age)"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.color.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    struct Tone {
        let label: String
        let color: Color
        let text: Color
    }

    static func tone(_ status: String) -> Tone {
        switch status {
        case "pending", "waiting": return Tone(label: "Pending", color: Theme.mut, text: Theme.mut)
        case "approved", "searching", "downloading": return Tone(label: "Approved", color: Theme.i1, text: Theme.accentText)
        case "fulfilled", "available": return Tone(label: "Available", color: Theme.txt, text: Theme.txt)
        case "deferred": return Tone(label: "Not available yet", color: Theme.stuck, text: Theme.missText)
        case "rejected", "declined": return Tone(label: "Declined", color: Theme.danger, text: Theme.danger)
        case "withdrawn", "cancelled": return Tone(label: "Withdrawn", color: Theme.dim, text: Theme.mut)
        default: return Tone(label: status.capitalized, color: Theme.mut, text: Theme.mut)
        }
    }
}
