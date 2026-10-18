import SwiftUI
import FusionhaKit

/// The ladder the deploy will actually build (web dialog's quality row):
/// groups share one rank, and a group-valued cutoff makes the whole group the
/// ceiling (marked UPGRADE UNTIL).
struct PresetLadderSection: View {
    let ladder: PresetLadderPreview

    var body: some View {
        Section {
            if let group = ladder.cutoffGroup {
                LabeledContent("Upgrade Until (cutoff)") { Text("\(group.name) · group").foregroundStyle(Theme.i2) }
                Text("the whole group is the ceiling — \(group.qualities.map { DetailText.quality($0) }.joined(separator: " · ")) all meet it")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                LabeledContent("Upgrade Until (cutoff)") { Text(DetailText.quality(ladder.cutoff)).foregroundStyle(Theme.i2) }
            }
            ForEach(ladder.rows.indices, id: \.self) { i in rankRow(ladder.rows[i]) }
            if ladder.groupCount > 0 {
                Text("Grouped tiers deploy at one shared rank — no upgrade between them, so the custom-format score decides which release wins.")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        } header: {
            Text("\(ladder.qualityCount) qualities" + (ladder.groupCount > 0 ? " · \(ladder.groupCount) group\(ladder.groupCount == 1 ? "" : "s")" : ""))
                .textCase(nil)
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private func rankRow(_ row: PresetLadderRow) -> some View {
        switch row {
        case .quality(let q):
            HStack {
                Text(DetailText.quality(q)).font(.system(size: 13))
                Spacer()
                if ladder.cutoffGroupIndex == nil && q == ladder.cutoff { cutMark }
            }
        case .group(let index, let name, let qualities):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.i2)
                    Text("= equal rank").font(.system(size: 11)).foregroundStyle(Theme.dim)
                    Spacer()
                    if ladder.cutoffGroupIndex == index { cutMark }
                }
                ForEach(qualities, id: \.self) { q in
                    HStack {
                        Text(DetailText.quality(q)).font(.system(size: 13))
                        Spacer()
                        if ladder.cutoffGroupIndex == nil && q == ladder.cutoff { cutMark }
                    }
                    .padding(.leading, 12)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quality group \(name) — members rank equal")
        }
    }

    private var cutMark: some View {
        Text("UPGRADE UNTIL").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.i2)
    }
}

/// The existing-profile choice: rebuild a profile this preset owns in place,
/// or adopt a same-named profile it does not own.
struct PresetTargetSection: View {
    let target: ProfileScoringSummary
    let owned: Bool
    let presetId: Int
    @Binding var replaceChoice: Bool
    @Binding var allowUnresolved: Bool
    @Binding var refusal: String?
    let onAdopted: () async -> Void
    @Environment(AppModel.self) private var model
    @State private var adopting = false

    var body: some View {
        Section {
            if owned {
                Picker("Deploy target", selection: $replaceChoice) {
                    Text("Update in place").tag(true)
                    Text("Deploy as new").tag(false)
                }
                .pickerStyle(.segmented)
                let uses = target.inUse ?? 0
                Text(replaceChoice
                     ? "Rebuilds “\(target.name)” — \(uses) item\(uses == 1 ? "" : "s") use it and keep pointing at it."
                     : "Leaves “\(target.name)” untouched and creates a second profile.")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
                if replaceChoice {
                    Toggle("Rebuild even if unresolved scores would drop", isOn: $allowUnresolved).tint(Theme.i1)
                }
            } else {
                Text("A profile named “\(target.name)” already exists but wasn’t created by this preset, so it can’t be rebuilt in place. Adopt it to let this preset manage it, or change the name above to deploy a new one.")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
                Button(adopting ? "Adopting…" : "Adopt this profile") { Task { await adopt() } }.disabled(adopting)
            }
        } header: {
            Text("Existing profile").textCase(nil)
        }
        .listRowBackground(Theme.card)
    }

    private func adopt() async {
        guard let client = model.client else { return }
        refusal = nil
        adopting = true
        defer { adopting = false }
        do {
            try await client.adoptPreset(id: presetId, qualityProfileId: target.id)
            await onAdopted()
        } catch {
            refusal = error.settingsMessage
        }
    }
}

/// A deploy that dropped scores holds the sheet on this list before Done.
struct PresetUnresolvedSection: View {
    let result: PresetDeployResult
    @State private var expanded = false

    var body: some View {
        let unresolved = result.unresolved ?? []
        Section {
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(unresolved, id: \.key) { u in
                    HStack {
                        Text(u.key).font(.system(size: 12.5, design: .monospaced))
                        Spacer()
                        CfSignedScore(score: u.score)
                    }
                }
            } label: {
                Text("Deployed **\(result.name)** · \(unresolved.count) score\(unresolved.count == 1 ? "" : "s") unresolved — view")
                    .font(.system(size: 13))
            }
        }
        .listRowBackground(Theme.card)
    }
}
