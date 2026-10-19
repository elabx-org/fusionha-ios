import SwiftUI
import FusionhaKit

/// One lifecycle step on the spine: its label (a HELD step names its hold),
/// the release, when, a failed step's reason in plain words, and `HeldStep`.
struct LifecycleStepRow: View {
    let event: HistoryEntry
    let last: Bool
    let itemTitle: String
    let groupBlock: ReleaseGroupBlock?

    private var held: HeldEventData? { event.eventType == "HELD" ? HeldEventData.parse(event.data) : nil }

    private var token: MonoToken {
        switch HistoryLogic.rawFilter(event.eventType) {
        case "failed": return .danger
        case "imported": return .done
        case "deleted": return .miss
        case "renamed": return .edition
        default: return event.eventType == "HELD" ? .miss : .grab
        }
    }

    var body: some View {
        let meta = HistoryLogic.eventMeta(event.eventType)
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .top) {
                if !last { Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity).padding(.top, 14) }
                StatusDot(token: token, size: 11)
                    .padding(3)
                    .background(token.color.opacity(0.18), in: Circle())
                    .padding(.top, 2)
            }
            .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(held?.stepTitle(held: event.held) ?? event.held?.stepTitle ?? meta.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(event.eventType == "HELD" ? Theme.miss : Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Text(ActFmt.relative(event.createdAt)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                }
                if let src = event.sourceTitle {
                    Text(src).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let quality = [event.quality.map { ActFmt.quality($0) }, event.size.map { ActFmt.bytes($0) }]
                    .compactMap { $0 }.joined(separator: " · ")
                if !quality.isEmpty { Text(quality).font(.system(size: 11)).foregroundStyle(Theme.dim) }
                if let fail = HistoryLifecycleModel.failureLine(event) {
                    Text(fail).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let held {
                    LifecycleHeldStep(event: event, data: held, itemTitle: itemTitle, groupBlock: groupBlock)
                }
            }
            .padding(.bottom, last ? 0 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The block in force now for a HELD event's release group (web `blockFor`).
    static func block(for event: HistoryEntry, in blocks: [ReleaseGroupBlock]) -> ReleaseGroupBlock? {
        guard event.eventType == "HELD", let group = HeldEventData.parse(event.data)?.releaseGroup?.lowercased(),
              !group.isEmpty else { return nil }
        return blocks.first { $0.group.lowercased() == group && ($0.scope == "global" || $0.mediaItemId == event.mediaItemId) }
    }
}
