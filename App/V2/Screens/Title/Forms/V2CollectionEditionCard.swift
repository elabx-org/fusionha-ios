import SwiftUI
import FusionhaKit

/// Add collection in v2's form sheet (Look Pass family 1): one card per
/// edition with its Toggle (the media badge, the tier, "default" as a quiet
/// tag), then Root folder and Quality profile as native menu pickers. The
/// same config v1's `ApproveEditionCard` edits.
struct V2CollectionEditionCard: View {
    let tier: QualityTier
    @Binding var config: ApproveTierConfig
    let roots: [RootFolder]
    let profiles: [QualityProfile]
    var tag: String?

    var body: some View {
        V2FormCard {
            Toggle(isOn: $config.enabled) {
                HStack(spacing: 8) {
                    EditionBadge(tier: tier, state: .missing, showsCount: false)
                    Text(tier.rawValue).font(.system(size: 16)).foregroundStyle(Theme.txt)
                    if let tag {
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Theme.txt.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .tint(Theme.primary)
            .v2FormRow(vertical: 10)
            .accessibilityLabel("Enable \(tier.rawValue)")
            V2FormDivider()
            V2FormPickerRow(title: "Root folder", selection: $config.rootId) {
                if config.rootId == nil { Text("Choose…").tag(Int?.none) }
                ForEach(roots) { root in Text(root.path).tag(Int?.some(root.id)) }
            }
            V2FormDivider()
            V2FormPickerRow(title: "Quality profile", selection: $config.profileId) {
                if config.profileId == nil { Text("Choose…").tag(Int?.none) }
                ForEach(profiles) { profile in Text(profile.name).tag(Int?.some(profile.id)) }
            }
        }
        .opacity(config.enabled ? 1 : 0.72)
    }
}

/// "Start search for missing on add", on its own card.
struct V2CollectionSearchToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        V2FormCard {
            Toggle("Start search for missing on add", isOn: $isOn)
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .tint(Theme.primary)
                .v2FormRow(vertical: 10)
        }
    }
}
