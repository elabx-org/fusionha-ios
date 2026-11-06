import SwiftUI
import FusionhaKit

/// One blocked group in the Release groups sheet: the name, where it
/// applies ("This title" or "Everywhere") with why and the note, and
/// Unblock (trash) as a glass button.
struct V2GroupBlockRow: View {
    let block: ReleaseGroupBlock
    let busy: Bool
    let unblock: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: TitleGroupBlocks.isEverywhere(block) ? "globe" : "film")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .frame(width: 32, height: 32)
                .background(Theme.txt.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.group)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action: unblock) {
                Group {
                    if busy { ProgressView().controlSize(.small) } else { Image(systemName: "trash") }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.dangerText)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .disabled(busy)
            .accessibilityLabel("Unblock \(block.group)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var detail: String {
        let why = block.reason == "mislabeled_resolution" ? "fake resolution" : "manual"
        let date = DetailText.instant(block.createdAt).map { $0.formatted(.dateTime.day().month(.abbreviated)) }
        let parts: [String?] = [TitleGroupBlocks.scopeLabel(block), why, date, block.note]
        return parts.compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }
}
