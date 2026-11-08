import SwiftUI
import FusionhaKit

// Switch metadata source in v2's form sheet (Look Pass family 1). The steps,
// calls and words are v1's `MetadataSwitchSheet`; these are only its Match
// and Review bodies drawn as inset-grouped cards.

/// Match: the matched series and the plan on one card, then "Not the right
/// show?" with the id field and Use (admins only).
struct V2MetadataSwitchMatch: View {
    let preview: MetadataSwitchPreview
    let plan: NumberingPlan?
    let target: String
    let label: String
    let renameCount: Int
    let blocked: Bool
    let isAdmin: Bool
    @Binding var manualId: String
    let use: () -> Void

    private var flagged: Int { (preview.files ?? []).filter { $0.confidence == "title-only-warn" }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if preview.matched == nil && target != "hybrid" {
                DialogBanner(text: "Couldn't find this series on \(label). Enter its \(label) id below.")
            }
            V2FormSection(label: "Match") {
                if let match = preview.matched {
                    HStack(spacing: 14) {
                        Color.clear.frame(width: 46, height: 69)
                            .overlay { DiscoverArt(url: TMDBImage.resized(match.poster, to: "w342")) }
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(match.title ?? "#\(match.id)").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text(verbatim: [match.year.map { "\($0)" }, "\(label) #\(match.id)"].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.mut)
                        }
                    }
                    .v2FormRow()
                    V2FormDivider()
                }
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planLine).font(.system(size: 16)).foregroundStyle(Theme.txt)
                        Text("\(renameCount) file\(renameCount == 1 ? "" : "s") to rename" + (flagged > 0 ? " · \(flagged) flagged" : ""))
                            .font(.system(size: 13)).foregroundStyle(flagged > 0 ? Theme.missText : Theme.mut)
                    }
                }
                .v2FormRow()
            }
            if blocked { DialogBanner(text: "Downloads are in flight for this series — wait for the queue to drain.") }
            if target != "hybrid" && isAdmin {
                V2FormSection(label: "Not the right show?", footer: "Admins only. Matching reloads the plan with that id.") {
                    HStack(spacing: 10) {
                        TextField("Not the right show? \(label) id", text: $manualId)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16))
                        Button("Use", action: use)
                            .buttonStyle(.glass)
                            .disabled(Int(manualId) == nil)
                    }
                    .v2FormRow(vertical: 8)
                }
            }
        }
    }

    private var planLine: String {
        guard let plan else { return "Building the plan…" }
        let text = MetadataSwitchLogic.summary(plan)
        return text.isEmpty ? "Nothing to change" : text
    }
}

/// Review: the seasons summary, then each file the switch would rename with
/// its Toggle; a title-only match is the orange row that needs you.
struct V2MetadataSwitchReview: View {
    let plan: NumberingPlan?
    let files: [MetadataSwitchFile]
    let renameCount: Int
    let blocked: Bool
    @Binding var excluded: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if blocked {
                DialogBanner(text: "Downloads are in flight for this series — wait for the queue to drain and try again.")
            }
            V2FormSection(label: "Seasons") {
                Group {
                    if let plan {
                        let text = MetadataSwitchLogic.summary(plan)
                        Text(text.isEmpty ? "Nothing to change." : text)
                            .font(.system(size: 16)).foregroundStyle(Theme.txt)
                    } else {
                        Text("Building the plan…").font(.system(size: 15)).foregroundStyle(Theme.mut)
                    }
                }
                .v2FormRow()
            }
            V2FormSection(label: "Files · \(renameCount) to rename") {
                if files.isEmpty {
                    Text("No files to rename.").font(.system(size: 15)).foregroundStyle(Theme.mut).v2FormRow()
                }
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    if index > 0 { V2FormDivider() }
                    row(file)
                }
            }
        }
    }

    private func row(_ file: MetadataSwitchFile) -> some View {
        let renameable = file.newName != nil
        let included = renameable && !excluded.contains(file.id)
        let flagged = file.confidence == "title-only-warn"
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                V2FormPath(path: file.rawName, color: Theme.mut)
                if let new = file.newName {
                    V2FormPath(path: "→ \(new)", color: Theme.txt)
                } else {
                    Text("Unmatched — kept as is").font(.system(size: 13)).foregroundStyle(Theme.dim)
                }
                if flagged {
                    Label("Matched by title only — check it", systemImage: "exclamationmark")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.missText)
                }
            }
            Spacer(minLength: 0)
            Toggle("Rename \(file.rawName)", isOn: Binding(get: { included }, set: { on in
                if on { excluded.remove(file.id) } else { excluded.insert(file.id) }
            }))
            .labelsHidden()
            .tint(Theme.i1)
            .disabled(!renameable)
        }
        .v2FormRow()
        .background(flagged ? Theme.miss.opacity(0.10) : Color.clear)
    }
}

/// The glass bar under the steps: what this step means on the left, the
/// step's action on the right.
struct V2MetadataSwitchBar<Action: View>: View {
    let title: String?
    let detail: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                if let title {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                }
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
