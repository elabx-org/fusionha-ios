import SwiftUI
import FusionhaKit

extension SourceAdminCopy.Tone {
    var color: Color {
        switch self {
        case .done: return Theme.done
        case .grab: return Theme.grab
        case .stuck: return Theme.stuck
        case .miss: return Theme.miss
        case .dim: return Theme.dim
        case .i1: return Theme.i1
        case .danger: return Theme.danger
        case .unaired: return Theme.unaired
        case .unmonitored: return Theme.mut
        }
    }
}

/// A state pill (web `.pill`): the label in its tone on a light wash.
struct SourceStatePill: View {
    let label: String
    let tone: SourceAdminCopy.Tone

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tone.color.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

/// "What happened to the items seen" (web `OutcomeBar`): proportional
/// segments in the outcome colours and a legend with counts.
struct SourceOutcomeBar: View {
    let outcomes: SourceOutcomes?

    var body: some View {
        let rows = SourceAdminCopy.outcomeRows(outcomes)
        let total = max(1, rows.map(\.count).reduce(0, +))
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(rows, id: \.key) { row in
                            SourceAdminCopy.outcomeTone(row.key).color
                                .frame(width: max(2, (geo.size.width - CGFloat(rows.count * 2)) * CGFloat(row.count) / CGFloat(total)))
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                ActFlow(spacing: 10, lineSpacing: 4) {
                    ForEach(rows, id: \.key) { row in
                        HStack(spacing: 4) {
                            Circle().fill(SourceAdminCopy.outcomeTone(row.key).color).frame(width: 7, height: 7)
                            Text(SourceAdminCopy.outcomeLabel(row.key)).foregroundStyle(Theme.mut)
                            Text("\(row.count)").fontWeight(.bold).foregroundStyle(Theme.txt)
                        }
                        .font(.system(size: 12))
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Outcome breakdown: " + rows.map { "\(SourceAdminCopy.outcomeLabel($0.key)) \($0.count)" }.joined(separator: ", "))
        }
    }
}

/// One fact: the value over its label.
struct SourceStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum SourceTime {
    /// "3 min ago" / "never".
    static func ago(_ iso: String?) -> String {
        guard let iso, let date = ServerTime.parse(iso) else { return "never" }
        return date.formatted(.relative(presentation: .named))
    }

    /// "in 10 min" / "—".
    static func until(_ iso: String?) -> String {
        guard let iso, let date = ServerTime.parse(iso) else { return "—" }
        return date.formatted(.relative(presentation: .named))
    }
}
