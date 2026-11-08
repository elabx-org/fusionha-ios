import SwiftUI
import FusionhaKit

/// Approve with changes, first group: what was asked as the header, then one
/// switch per version ("HD-1080p · Asked for · HD-1080p-Movies"). An asked
/// version stays on (the server always adds it).
struct V2ApproveVersionsSection: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let profiles: [QualityProfile]
    let asked: String
    @Binding var hd: ApproveTierConfig
    @Binding var uhd: ApproveTierConfig

    var body: some View {
        Section {
            row(.hd, $hd)
            row(.uhd, $uhd)
        } header: {
            Text(asked)
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
                .textCase(nil)
                .padding(.bottom, 4)
        }
        .listRowBackground(AccountStyle.cell)
    }

    private func row(_ tier: QualityTier, _ config: Binding<ApproveTierConfig>) -> some View {
        let isAsked = request.tiers.contains(tier)
        return Toggle(isOn: config.enabled) {
            V2ApproveIconLabel(icon: "film", tint: Theme.dim, title: tier.rawValue,
                               subtitle: subtitle(tier, isAsked: isAsked, profileId: config.wrappedValue.profileId))
        }
        .tint(Theme.primary)
        .disabled(isAsked)
    }

    private func subtitle(_ tier: QualityTier, isAsked: Bool, profileId: Int?) -> String {
        let profile = profiles.first { $0.id == profileId }?.name
        if isAsked { return ["Asked for", profile].compactMap { $0 }.joined(separator: " · ") }
        guard tier == .uhd else { return "Not asked for" }
        let fourK: String
        switch triage?.fourK.state {
        case "available": fourK = "4K is out"
        case "tracked": fourK = "4K already tracked"
        case "unseen": fourK = "no 4K release yet"
        default: fourK = "4K not checked yet"
        }
        return "Not asked for · \(fourK)"
    }
}

/// Second group: where each version goes, Monitor and Search when approved;
/// the cost sentence sits under it.
struct V2ApprovePlaceSection: View {
    @Binding var hd: ApproveTierConfig
    @Binding var uhd: ApproveTierConfig
    let roots: [RootFolder]
    let profiles: [QualityProfile]
    @Binding var monitor: Bool
    @Binding var search: Bool
    let cost: String

    private var both: Bool { hd.enabled && uhd.enabled }

    var body: some View {
        Section {
            if hd.enabled { place(.hd, $hd) }
            if uhd.enabled { place(.uhd, $uhd) }
            Toggle(isOn: $monitor) {
                V2ApproveIconLabel(icon: "bookmark.fill", tint: Theme.i1, title: "Monitor")
            }
            .tint(Theme.primary)
            Toggle(isOn: $search) {
                V2ApproveIconLabel(icon: "magnifyingglass", tint: Theme.i1, title: "Search when approved")
            }
            .tint(Theme.primary)
        } footer: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(Theme.accentText).accessibilityHidden(true)
                Text(cost).foregroundStyle(Theme.txt).fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .padding(.top, 6)
        }
        .listRowBackground(AccountStyle.cell)
    }

    @ViewBuilder
    private func place(_ tier: QualityTier, _ config: Binding<ApproveTierConfig>) -> some View {
        let prefix = both ? (tier == .uhd ? "4K " : "HD ") : ""
        Picker(selection: config.rootId) {
            if config.wrappedValue.rootId == nil { Text("Choose…").tag(Int?.none) }
            ForEach(roots) { root in Text(root.path).tag(Int?.some(root.id)) }
        } label: {
            V2ApproveIconLabel(icon: "folder.fill", tint: Theme.dim, title: prefix + "Root folder")
        }
        Picker(selection: config.profileId) {
            if config.wrappedValue.profileId == nil { Text("Choose…").tag(Int?.none) }
            ForEach(profiles) { profile in Text(profile.name).tag(Int?.some(profile.id)) }
        } label: {
            V2ApproveIconLabel(icon: "slider.horizontal.3", tint: Theme.dim, title: prefix + "Quality profile")
        }
    }
}

/// A Form row's label: the hued icon tile (as v2's Account rows), the title
/// and an optional second line.
struct V2ApproveIconLabel: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.isMono ? Theme.bg : Theme.onTint(tint))
                .frame(width: 28, height: 28)
                .background(Theme.isMono ? Theme.mut : tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Theme.txt)
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.mut).lineLimit(2)
                }
            }
        }
    }
}
