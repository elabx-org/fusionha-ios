import SwiftUI
import FusionhaKit

/// One preset card (web `PresetsTab` card): kind, name with rename, where it
/// was captured from, tier tag, Upgrade Until · Qualities · Tuned formats, the
/// top four scores, and View / Deploy.
struct PresetCardSection: View {
    let preset: PresetInfo
    /// trash_id → guide name for the preset's kind.
    let names: [String: String]
    let from: String?
    let deployed: Bool
    let onView: () -> Void
    let onDeploy: () -> Void
    let onRename: () -> Void

    var body: some View {
        Section {
            header
            HStack(spacing: 0) {
                stat(DetailText.quality(preset.manifest.cutoff), "Upgrade Until", tint: Theme.i2)
                stat("\(preset.manifest.allowedQualities.count)", "Qualities")
                stat("\(preset.manifest.formatScores.count)", "Tuned formats")
            }
            if !preset.manifest.topScores.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top scoring").font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Theme.dim)
                    FetchFlow(spacing: 5, lineSpacing: 5) {
                        let top = preset.manifest.topScores
                        ForEach(top.indices, id: \.self) { i in
                            CfScoreChip(name: names[top[i].key] ?? top[i].key, score: top[i].score)
                        }
                    }
                }
            }
            Text("creates profile **\(preset.deployName)** · \(preset.manifest.formatScores.count) scored CFs · upgrades \(preset.manifest.upgradeSummary)")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
            HStack {
                Button("View", action: onView)
                    .buttonStyle(.web(.ghost))
                    .accessibilityLabel("View \(preset.name)")
                Spacer()
                if deployed {
                    Label("Deployed", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(Theme.done)
                } else {
                    Button("Deploy", action: onDeploy)
                        .buttonStyle(.web(.primary))
                        .accessibilityLabel("Deploy \(preset.deployName)")
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: kindSymbol).foregroundStyle(Theme.mut).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name).font(.subheadline.weight(.bold)).foregroundStyle(Theme.txt)
                    Button(action: onRename) {
                        Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(Theme.dim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rename \(preset.name)")
                }
                Text("from \(from ?? preset.mediaKind)").font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            FetchPill(text: preset.tierLabel, tone: tierTone)
        }
    }

    private var kindSymbol: String {
        switch preset.mediaKind {
        case "series": return "tv"
        case "anime": return "paintbrush.pointed"
        default: return "film"
        }
    }

    private var tierTone: FetchPill.Tone {
        switch preset.tierLabel {
        case "4K": return .accent
        case "ANIME": return .warn
        default: return .off
        }
    }

    private func stat(_ value: String, _ label: String, tint: Color = Theme.txt) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 10.5)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity)
    }
}
