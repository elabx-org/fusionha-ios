import SwiftUI
import FusionhaKit

/// One blocked group in the Release groups sheet (web 0.4.239): the name
/// with its "This title" / "Everywhere" chip, why, when and the note, and
/// "Unblock <GROUP>" (trash), which asks in place: Keep blocked / Unblock.
struct V2GroupBlockRow: View {
    let block: ReleaseGroupBlock
    let busy: Bool
    let unblock: () -> Void
    @State private var confirming = false
    @Environment(\.detailReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(block.group)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                        V2ReleaseCard.filledTag(Text(TitleGroupBlocks.scopeLabel(block)), color: Theme.txt)
                    }
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.mut)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if !confirming {
                    pill("Unblock \(block.group)", icon: "trash", tint: Theme.dangerText) { confirming = true }
                }
            }
            if confirming {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    pill("Keep blocked", icon: nil, tint: Theme.txt) { confirming = false }
                    pill("Unblock", icon: busy ? nil : "trash", tint: Theme.dangerText, busy: busy, action: unblock)
                }
                .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(reduce ? nil : .snappy(duration: 0.2), value: confirming)
    }

    private func pill(_ title: String, icon: String?, tint: Color, busy: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if busy { ProgressView().controlSize(.mini) } else if let icon { Image(systemName: icon) }
                Text(title).lineLimit(1)
            }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(busy)
    }

    private var detail: String {
        let why = block.reason == "mislabeled_resolution" ? "fake resolution" : nil
        let date = DetailText.instant(block.createdAt).map { $0.formatted(.dateTime.day().month(.abbreviated)) }
        let parts: [String?] = [why, date.map { "since \($0)" }, block.note]
        return parts.compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }
}
