import SwiftUI
import UIKit
import FusionhaKit

/// One release in the v2 interactive search (mock browse-sheets.js
/// `relCard`): the name with its score, a line of quality, size, age,
/// indexer and protocol, why it was passed over (or that it is
/// blocklisted), then the reason's short tag, ⋯ and Grab / Grab anyway.
/// A W1 card. The version's current file wears a green ring and says so
/// (mock `relCard({cur: true})`), its button Grab again.
struct V2ReleaseCard: View {
    let release: ReleasePreview
    let downloading: Bool
    let blocklistReason: String
    /// The version's tier when this release is its current file.
    var currentTier: QualityTier?
    /// Where the release's group is blocked ("This title" / "Everywhere"):
    /// the card stays, dimmed, and says so.
    var groupBlock: String?
    /// "Block <GROUP>" in ⋯, handed the group.
    var blockGroup: ((String) -> Void)?
    let onGrab: () -> Void

    private var anyway: Bool { release.rejected || release.blocklisted == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(release.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                score
            }
            meta
                .padding(.top, -1)
            if let tier = currentTier {
                why("checkmark.circle", "This is your current \(tier.badgeLetters) file", color: Theme.doneText)
            } else if let groupBlock {
                why("nosign", "Blocked group · \(groupBlock)", color: Theme.mut)
            } else if release.rejected, let reason = release.reason, !reason.isEmpty {
                why("exclamationmark.circle", reason, color: Theme.stuck)
                LearnEditionAliasButton(release: release)
            }
            if release.blocklisted == true { why("nosign", blocklistReason, color: Theme.mut) }
            HStack(spacing: 8) {
                if groupBlock == nil, let tag = V2ReleaseReason.short(release) {
                    Self.filledTag(Text(tag), color: Theme.mut)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                more
                grab
            }
        }
        .padding(EdgeInsets(top: 11, leading: 14, bottom: 12, trailing: 12))
        .opacity(groupBlock != nil ? 0.55 : 1)
        .background { ModuleSurface(radius: 18) }
        .overlay {
            if currentTier != nil {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.done.opacity(0.55), lineWidth: 1.5)
            }
        }
    }

    /// Kit `.tg`: a small filled tag, the text colour at 9%.
    static func filledTag(_ text: Text, color: Color) -> some View {
        text
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var score: some View {
        let value = release.cfScore ?? 0
        return VStack(alignment: .trailing, spacing: 0) {
            Text(ReleaseSearch.score(value))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(value < 0 ? Theme.danger : Theme.txt)
            Text("score").font(.system(size: 10.5)).foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(ReleaseSearch.score(value))")
    }

    private var meta: some View {
        let parts: [String?] = [release.size.map { DetailText.bytes($0) }, ReleaseSearch.age(release.ageSeconds),
                     ReleaseSearch.indexer(release),
                     release.protocolName.isEmpty ? nil : ReleaseSearch.protocolLabel(release.protocolName),
                     ReleaseSearch.isTorrent(release) ? release.seeders.map { "\($0) seed" } : nil]
        return FlowRow(spacing: 6, lineSpacing: 4) {
            if let quality = release.quality {
                Self.filledTag(Text(DetailText.quality(quality)), color: Theme.txt)
            }
            Text(parts.compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
            if let group = release.releaseGroup {
                Text(group).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
            }
        }
    }

    private func why(_ icon: String, _ text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var more: some View {
        Menu {
            Button("Copy name", systemImage: "doc.on.doc") { UIPasteboard.general.string = release.title }
            if let blockGroup, groupBlock == nil {
                V2BlockGroupButton(group: release.releaseGroup, open: blockGroup)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel("More for \(release.title)")
    }

    private var label: String { currentTier != nil ? "Grab again" : anyway ? "Grab anyway" : "Grab" }

    @ViewBuilder
    private var grab: some View {
        if downloading {
            Label("Downloading", systemImage: "arrow.down.circle.dotted")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 6)
        } else {
            Button(action: onGrab) {
                Label(label, systemImage: "arrow.down")
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .accessibilityLabel("\(label): \(release.title)")
        }
    }
}

/// The card's short tag for why a release was passed over (mock `REASON_SHORT`).
enum V2ReleaseReason {
    static func short(_ release: ReleasePreview) -> String? {
        if release.blocklisted == true { return "Blocklisted" }
        guard release.rejected, let reason = release.reason, !reason.isEmpty else { return nil }
        let lower = reason.lowercased()
        if TitleGroupBlocks.isGroupBlockReason(reason) { return "Blocked group" }
        if lower.hasPrefix("not an upgrade") { return "Not an upgrade" }
        if lower.contains("not wanted") { return "Quality not in profile" }
        if lower.contains("does not match") { return "Wrong title or year" }
        if lower.hasPrefix("custom format") { return "Score below the minimum" }
        return reason.count > 28 ? nil : reason
    }
}
