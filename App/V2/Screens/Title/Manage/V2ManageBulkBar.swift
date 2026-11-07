import SwiftUI
import FusionhaKit

/// The glass bar while files are selected (mock frame 1): "23 selected",
/// "75.4 GB · Seasons 1 and 4", Edit (the bulk editor) and Delete (the
/// clear-out confirmation). Fits the folded Duo: the words shrink before the
/// buttons do.
struct V2ManageBulkBar: View {
    let summary: ManageSelectionSummary
    let busy: Bool
    let edit: () -> Void
    let delete: () -> Void

    private var detailLine: String {
        summary.seasonsText.isEmpty ? summary.size : "\(summary.size) · \(summary.seasonsText)"
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(summary.count) selected")
                        .font(.system(size: 14.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                    Text(detailLine)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Button(action: edit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 13)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Capsule())
                Button(action: delete) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.onDanger)
                        .padding(.horizontal, 13)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Theme.danger).interactive(), in: Capsule())
            }
            .disabled(busy)
            .padding(.trailing, 8)
            .frame(height: 56)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

/// The bar while a delete runs.
struct V2ManageProgressBar: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}
