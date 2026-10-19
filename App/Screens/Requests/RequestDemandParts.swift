import SwiftUI
import FusionhaKit

/// "Joined · N asked" (web `JoinedBadge`): an accent-ghost pill a joiner sees
/// in place of the source, on the card and in the thread.
struct RequestJoinedPill: View {
    let request: MediaRequest

    var body: some View {
        Label {
            Text(verbatim: "Joined · \(request.demand?.count ?? 1) asked")
        } icon: {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
        }
        .font(.system(size: 11.5, weight: .bold))
        .foregroundStyle(Theme.accentText)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Theme.i1.opacity(0.14), in: Capsule())
        .lineLimit(1)
        .fixedSize()
    }
}

/// "Also requested by N others · everyone is notified when it’s available"
/// (web `DemandRow`): a count only, never who. The owner's card and thread
/// show it; nothing at one asker.
struct RequestDemandLine: View {
    let demand: RequestDemand?

    var body: some View {
        let others = (demand?.count ?? 1) - 1
        if others >= 1 {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundStyle(Theme.mut)
                (Text(verbatim: "Also requested by \(others) \(others == 1 ? "other" : "others")").fontWeight(.semibold)
                 + Text(" · everyone is notified when it’s available").foregroundColor(Theme.mut))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
