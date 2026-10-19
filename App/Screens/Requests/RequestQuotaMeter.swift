import SwiftUI
import FusionhaKit

/// "N of M requests left this week" with a pip per request, when the
/// requester has a limit (web `QuotaMeter`).
struct RequestQuotaMeter: View {
    let quota: RequestQuota

    var body: some View {
        if let limit = quota.limit, limit > 0 {
            let left = max(0, limit - quota.used)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    (Text(verbatim: "\(left)").fontWeight(.bold).foregroundColor(Theme.txt)
                     + Text(verbatim: " of \(limit) requests left this week").foregroundColor(Theme.mut))
                        .font(.system(size: 14))
                    Spacer(minLength: 8)
                }
                HStack(spacing: 4) {
                    ForEach(0..<limit, id: \.self) { i in
                        Capsule()
                            .fill(i < quota.used ? (left == 0 ? Theme.miss : Theme.i1) : Theme.line)
                            .frame(height: 5)
                    }
                }
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var footnote: String {
        var parts: [String] = []
        if let day = RequestLifecycle.resetWeekday(quota.resetsAt) { parts.append("Resets \(day)") }
        parts.append("auto-requests count too")
        if quota.waiting > 0 { parts.append("\(quota.waiting) waiting") }
        return parts.joined(separator: " · ")
    }
}

/// Under a source filter (web `SourceNote`): removing a title from a list
/// never cancels its request.
struct RequestSourceNote: View {
    var body: some View {
        Label(RequestSourceFilter.note, systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
    }
}
