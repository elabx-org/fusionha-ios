import SwiftUI

/// Select mode's bar (mock queue `bulk`): a glass capsule at the bottom with
/// the count, Select all, Re-grab and Remove. Remove opens the remove panel
/// (the right page on the open Duo, a sheet on the phone).
struct V2QueueBulkBar: View {
    let count: Int
    let busy: Bool
    let selectAll: () -> Void
    let regrab: () -> Void
    let remove: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Button("Select all", systemImage: "checkmark.circle", action: selectAll)
                } label: {
                    Text("\(count) selected")
                        .font(.system(size: 14.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                        .padding(.leading, 18)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(count) selected")
                action("Re-grab", "arrow.clockwise", tint: Theme.txt, run: regrab)
                action("Remove", "trash", tint: Theme.dangerText, run: remove)
            }
            .padding(.trailing, 8)
            .frame(height: 56)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func action(_ label: String, _ icon: String, tint: Color, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(label, systemImage: icon)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(count == 0 || busy)
        .opacity(count == 0 ? 0.5 : 1)
    }
}
