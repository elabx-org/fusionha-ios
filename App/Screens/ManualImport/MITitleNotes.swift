import SwiftUI
import FusionhaKit

/// "The file says 'Mafia', that's S06E06 in your library, not S06E05" (the
/// web's `TitleNote`, fusionha 0.4.193): first in the decision block while the
/// file's own title names another episode. Keep current uses the replace path,
/// Re-match the episode override, Dismiss imports it as numbered.
struct MITitleNote: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        if let tc = row.titleCheck, ManualImportRules.titleBlocked(row) {
            let code = tc.matchesEpisode?.code ?? "another episode"
            let here = ManualImportRules.episodeCode(row) ?? "this episode"
            let group = row.existingFile?.releaseGroup ?? row.parsed.releaseGroup ?? "release"
            MINotePanel(text: "The file says '\(tc.says ?? "")', that's \(code) in your library, not \(here)",
                        detail: tc.sameReleaseExists == true ? "\(code) already has this exact \(group) file" : nil) {
                if row.existingFile != nil {
                    MINoteButton(label: "Keep current", recommended: row.recommended == "keep_current",
                                 accessibility: "Keep current, remove download", row: row) {
                        ["replace_choice": "keep_current"]
                    }
                } else {
                    MINoteButton(label: "Dismiss this check", recommended: false, row: row) {
                        ["dismiss_episode_title": true]
                    }
                }
                if let fields = ManualImportRules.rematchFields(row) {
                    MINoteButton(label: "Re-match to \(code)", recommended: row.recommended == "rematch", row: row) { fields }
                }
            }
        }
    }
}

/// The file runs about N episodes: offer the multi-episode assign (the web's `AssignNote`).
struct MIAssignNote: View {
    let row: ManualImportRow

    var body: some View {
        if let plan = ManualImportRules.assignPlan(row) {
            let text = row.runtimeCheck.map {
                "The file runs \(Int((Double($0.seconds) / 60).rounded())) min, about \(plan.episodes.count) episodes"
            } ?? "The file looks like \(plan.episodes.count) episodes"
            MINotePanel(text: text, detail: nil) {
                MINoteButton(label: "Assign \(ManualImportRules.episodesLabel(plan.episodes))",
                             recommended: plan.recommended, row: row) {
                    ["episodes": .array(plan.episodes.map { .int($0) })]
                }
            }
        }
    }
}

/// An attention-washed note with its actions.
struct MINotePanel<Actions: View>: View {
    let text: String
    let detail: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(.footnote).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ActFlow(spacing: 8, lineSpacing: 8) { actions }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// A note action: primary with a "Recommended" tag when the server suggests it.
struct MINoteButton: View {
    let label: String
    let recommended: Bool
    var accessibility: String? = nil
    let row: ManualImportRow
    let fields: () -> [String: SettingsJSON]
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        Button { Task { await session.patch(row, fields()) } } label: {
            HStack(spacing: 6) {
                Text(label)
                if recommended {
                    Text("Recommended").font(.caption2.weight(.bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.onPrimary.opacity(0.2), in: Capsule())
                }
            }
        }
        .buttonStyle(ActButtonStyle(kind: recommended ? .primary : .subtle))
        .disabled(session.pendingRows.contains(row.rowId))
        .accessibilityLabel((accessibility ?? label) + (recommended ? ", recommended" : ""))
    }
}
