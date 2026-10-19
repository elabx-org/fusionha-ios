import SwiftUI
import FusionhaKit

/// One release in the interactive search (InteractiveSearch.tsx mobile card):
/// title + group, quality/flags/size/age/indexer/seeders, the rejection or
/// blocklist reason (with "learn this term" on an edition mismatch), the
/// signed custom-format score and the icon-only Grab tile.
struct ReleaseCard: View {
    let release: ReleasePreview
    let showSeed: Bool
    let downloading: Bool
    let trigger: String?
    let autoTarget: ReleaseSearch.AutoTarget?
    let blocklistReason: String
    let onGrab: () -> Void

    var body: some View {
        let rejected = release.rejected
        let blocklisted = release.blocklisted == true
        VStack(alignment: .leading, spacing: 8) {
            Text(release.title)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if release.releaseGroup != nil || downloading || autoTarget != nil || blocklisted {
                FlowRow(spacing: 7, lineSpacing: 6) {
                    if let group = release.releaseGroup {
                        Text(group)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.edition)
                    }
                    if downloading, let trigger { ActProvenance(trigger: trigger) }
                    if let autoTarget { AutoTargetHint(info: autoTarget) }
                    if blocklisted {
                        HStack(spacing: 4) {
                            Image(systemName: "nosign").font(.system(size: 11, weight: .semibold))
                            Text("BLOCKLISTED").tracking(0.3)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.txt)
                    }
                }
            }
            FlowRow(spacing: 7, lineSpacing: 6) {
                SearchQualityChip(quality: release.quality)
                ForEach(release.flags ?? [], id: \.self) { flag in
                    Text(flag.uppercased())
                        .font(.system(size: 11))
                        .tracking(0.3)
                        .foregroundStyle(Theme.grab)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Theme.grab.opacity(0.14), in: Capsule())
                }
                meta(release.size.map { DetailText.bytes($0) } ?? "—")
                meta(ReleaseSearch.age(release.ageSeconds))
                meta(ReleaseSearch.indexer(release))
                if showSeed { meta(release.seeders.map { "\($0) seed" } ?? "—") }
            }
            if rejected {
                reasonLine("xmark", release.reason ?? "", color: Theme.miss)
                LearnEditionAliasButton(release: release)
            }
            if blocklisted {
                reasonLine("nosign", blocklistReason, color: Theme.txt)
            }
            HStack(spacing: 12) {
                let score = release.cfScore ?? 0
                Text(ReleaseSearch.score(score))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(score < 0 ? Theme.danger : Theme.done)
                Spacer(minLength: 0)
                SearchGrabTile(title: release.title, anyway: rejected || blocklisted, blocklisted: blocklisted,
                         downloading: downloading, onGrab: onGrab)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .strokeBorder(Theme.line))
        .opacity(rejected ? 0.72 : 1)
    }

    private func meta(_ text: String) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
    }

    private func reasonLine(_ icon: String, _ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(color)
    }
}

/// `QualityChip` with no tier: tinted by the quality itself (HD purple, 4K cyan, else muted).
