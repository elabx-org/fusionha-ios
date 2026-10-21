import SwiftUI
import FusionhaKit

/// The web's DeleteItemDialog: "Delete {title}?", the delete-files checkbox, Cancel /
/// Delete (danger, "Deleting…" while pending).
struct DeleteTitleDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: DeleteTarget
    @State private var deleteFiles = false
    @State private var deleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete \(target.title)?")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.top, 8)
            Text("This removes the title and all its versions from your library. This cannot be undone.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $deleteFiles) {
                Text("Also delete the downloaded files from disk")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.txt)
            }
            .toggleStyle(WebCheckboxStyle())
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .panel(Theme.panel2, radius: Theme.radius)
                }
                .buttonStyle(PressScaleStyle())
                Button {
                    Task {
                        deleting = true
                        let ok = await model.delete(target, deleteFiles: deleteFiles)
                        deleting = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text(deleting ? "Deleting…" : "Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.onDanger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.danger, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(deleting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
