import SwiftUI
import FusionhaKit

/// "Filtered to Dark Matter · clear" (web `ItemFilterChip`): the History feed
/// is scoped to one title.
struct HistoryItemFilterChip: View {
    let filter: HistoryItemFilter
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            (Text("Filtered to ") + Text(filter.label).bold())
                .font(.system(size: 13))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Text("·").font(.system(size: 13)).foregroundStyle(Theme.dim)
            Button(action: onClear) {
                Label("clear", systemImage: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear the title filter")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .glassControl()
    }
}
