import SwiftUI
import FusionhaKit

/// The switch's Review step (SwitchReviewStep.tsx): the numbering plan's
/// summary, then each file the switch would rename, each one able to be left
/// out (flagged title-only matches are marked).
struct MetadataSwitchReview: View {
    let plan: NumberingPlan?
    let files: [MetadataSwitchFile]
    let renameCount: Int
    let blocked: Bool
    @Binding var excluded: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if blocked {
                DialogBanner(text: "Downloads are in flight for this series — wait for the queue to drain and try again.")
            }
            DetailMonoHeading(text: "Seasons")
            if let plan {
                Text(MetadataSwitchLogic.summary(plan).isEmpty ? "Nothing to change." : MetadataSwitchLogic.summary(plan))
                    .font(.system(size: 13)).foregroundStyle(Theme.txt)
            } else {
                DialogNote("Building the plan…")
            }
            DetailMonoHeading(text: "Files · \(renameCount) to rename").padding(.top, 8)
            if files.isEmpty {
                Text("No files to rename.").font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            ForEach(files) { file in row(file) }
        }
    }

    private func row(_ file: MetadataSwitchFile) -> some View {
        let renameable = file.newName != nil
        let included = renameable && !excluded.contains(file.id)
        return HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { included }, set: { on in
                if on { excluded.remove(file.id) } else { excluded.insert(file.id) }
            }))
            .labelsHidden()
            .tint(Theme.i1)
            .disabled(!renameable)
            VStack(alignment: .leading, spacing: 3) {
                Text(file.rawName).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                if let new = file.newName {
                    Text("→ \(new)").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.txt)
                } else {
                    Text("Unmatched — kept as is").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
                if file.confidence == "title-only-warn" {
                    Label("Matched by title only — check it", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.miss)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(file.confidence == "title-only-warn" ? Theme.miss : nil, mono: .miss, radius: 12)
    }
}
