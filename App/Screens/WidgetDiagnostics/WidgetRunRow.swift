import SwiftUI
import FusionhaKit

/// One widget run: widget and size, when, the outcome (coloured), where it got
/// to, the error and whether its entry was drawn.
struct WidgetRunRow: View {
    let record: WidgetRunRecord
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(record.kind) · \(record.family)").font(.callout.weight(.semibold))
                if record.call != "timeline" {
                    Text(record.call).font(.caption2).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 4)
                Text(record.log.started, format: .relative(presentation: .numeric))
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
            }
            Text(detail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// `never finished @page upnext 2.1s · not drawn`.
    private var detail: String {
        var parts = ["\(record.status(now: now)) @\(record.log.stage) \(record.log.page) \(String(format: "%.1f", record.log.seconds))s"]
        if let error = record.log.error { parts.append(error) }
        if record.log.outcome != .running || record.abandoned(now: now) {
            parts.append(record.rendered ? "drawn" : "not drawn")
        }
        return parts.joined(separator: " · ")
    }

    private var color: Color {
        if record.abandoned(now: now) { return Theme.danger }
        switch record.log.outcome {
        case .ok: return record.rendered ? Theme.done : Theme.miss
        case .running: return Theme.grab
        case .failed, .timedOut: return Theme.stuck
        }
    }
}
