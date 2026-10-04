import SwiftUI
import FusionhaKit

// The pieces of the Manual search sheet (DetailSearch.swift): the web's
// InteractiveSearch.module.css blocks, one view each.

struct SearchToast: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// `.toast`: the in-sheet confirmation, centred above the bottom edge.
struct SearchToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.txt)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 16)
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// `.note`: a muted 13pt line between the sections.
struct SearchNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 14)
            .padding(.horizontal, 2)
    }
}

/// A glass filter chip opening a native menu (`.filterTrigger`).
struct SearchFilterMenu<Content: View>: View {
    let label: String
    var prefix: String?
    let accessibility: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) {
            HStack(spacing: 6) {
                if let prefix { Text(prefix).foregroundStyle(Theme.mut) }
                Text(label).foregroundStyle(Theme.txt)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(height: 28)
        }
        .buttonStyle(.glass)
        .fixedSize()
        .accessibilityLabel(accessibility)
        .accessibilityValue(label)
    }
}

/// `.scan`: pulsing indexer chips + the status line (querying → ranked count).
struct SearchScanBanner: View {
    @Environment(\.detailReduceMotion) private var reduce
    let scanning: Bool
    let chips: Int
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            let count = scanning ? 4 : min(chips, 6)
            if scanning && !reduce {
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    HStack(spacing: 6) {
                        ForEach(0..<count, id: \.self) { i in
                            // `scanpulse`: 1.1s, staggered 0.16s, opacity .4→1 and 10%→32% cyan.
                            let phase = ((t - Double(i) * 0.16) / 1.1).truncatingRemainder(dividingBy: 1)
                            let k = 0.5 - 0.5 * cos(2 * .pi * (phase < 0 ? phase + 1 : phase))
                            chip(Theme.grab.opacity((0.10 + 0.22 * k) * (0.4 + 0.6 * k)))
                        }
                    }
                }
            } else {
                ForEach(0..<count, id: \.self) { _ in chip(Theme.grab.opacity(0.14)) }
            }
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 6)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .panel(Theme.panel2, radius: Theme.radius)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }

    private func chip(_ fill: Color) -> some View {
        Capsule().fill(fill).frame(width: 26, height: 8)
    }
}

/// `.scopeStatus` box chrome: amber-washed panel with a leading clock glyph.
struct SearchAmberBox<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(Theme.miss)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.txt)
        .lineSpacing(3)
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(Theme.panel2.mix(0.92, Theme.miss), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .strokeBorder(Theme.miss.opacity(0.38)))
        .padding(.bottom, 12)
    }
}

/// `ScopeStatusStrip`: why automatic search is idle for this scope.
struct ScopeStatusStrip: View {
    let status: ReleaseScopeStatus

    var body: some View {
        let lines = ReleaseSearch.scopeStatusLines(status) { iso in
            Format.timestamp(iso)?.formatted(date: .omitted, time: .shortened) ?? iso
        }
        if !lines.isEmpty {
            SearchAmberBox {
                ForEach(lines, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                if let last = ReleaseSearch.lastRunSummary(status) {
                    let ago = DetailText.relative(status.lastRunAt)
                    Text(ago.isEmpty ? last : "\(last) · \(ago)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// `IndexerCooldownNotice`: indexers the failure backoff is skipping.
struct CooldownNotice: View {
    let indexers: [IndexerUnavailable]

    var body: some View {
        SearchAmberBox {
            Text("\(indexers.count) \(indexers.count == 1 ? "indexer" : "indexers") skipped — in cooldown after repeated failures.")
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 7, lineSpacing: 7) {
                ForEach(indexers.prefix(6)) { ix in
                    HStack(spacing: 5) {
                        Circle().fill(Theme.miss).frame(width: 6, height: 6)
                        Text("\(ix.name) · \(ReleaseSearch.retryHint(Format.timestamp(ix.disabledTill)))")
                    }
                    .skipChip()
                    .help(ix.reason ?? "")
                }
                if indexers.count > 6 { Text("+\(indexers.count - 6) more").skipChip() }
            }
            Text("Re-test in Settings › Indexers to clear")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.mut)
        }
    }
}

extension View {
    /// `.skipChip`: a small panel2 capsule.
    func skipChip() -> some View {
        font(.system(size: 11.5))
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Theme.panel2, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line))
    }

    @ViewBuilder
    func detailSpinIf(_ on: Bool) -> some View {
        if on { detailSpin(period: 0.8) } else { self }
    }
}

/// `.cfWarn`: every release scored +0, so the profile has no format scores.
struct SearchCFWarning: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(Theme.miss)
                .padding(.top, 1)
            Text("Every release scored +0 — this version’s quality profile has no custom-format scores, so custom formats can’t rank or reject releases. Add scores in Custom Formats.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.txt)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.panel2.mix(0.92, Theme.miss), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.miss.opacity(0.4)))
        .padding(.bottom, 12)
    }
}

/// The web's `ReleaseCard` (the phone layout of a results row).
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
                            Image(systemName: "nosign").font(.system(size: 10, weight: .semibold))
                            Text("BLOCKLISTED").tracking(0.3)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.txt)
                    }
                }
            }
            FlowRow(spacing: 7, lineSpacing: 6) {
                SearchQualityChip(quality: release.quality)
                ForEach(release.flags ?? [], id: \.self) { flag in
                    Text(flag.uppercased())
                        .font(.system(size: 10.5))
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
            .strokeBorder(blocklisted ? Theme.miss.opacity(0.45) : Theme.line))
        .opacity(rejected ? 0.72 : 1)
    }

    private func meta(_ text: String) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
    }

    private func reasonLine(_ icon: String, _ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: icon).font(.system(size: 10.5, weight: .semibold))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(color)
    }
}

/// `QualityChip` with no tier: tinted by the quality itself (HD purple, 4K cyan, else muted).
struct SearchQualityChip: View {
    let quality: String?
    var body: some View {
        let tone = ReleaseSearch.tone(quality)
        let color = tone.map(DetailTokens.tier) ?? Theme.mut
        Text(DetailText.quality(quality))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.3)))
    }
}

/// `AutoTargetHint`: where a release of the other tier will actually be filed.
struct AutoTargetHint: View {
    let info: ReleaseSearch.AutoTarget
    var body: some View {
        let color = info.targetLabel == nil ? Theme.mut : DetailTokens.tier(info.tier)
        Text(info.targetLabel.map { "→ \($0)" } ?? "no \(info.tier.tierShort) version")
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(color.opacity(info.targetLabel == nil ? 0.10 : 0.14), in: Capsule())
            .overlay {
                if info.targetLabel == nil {
                    Capsule().strokeBorder(DetailTokens.line2, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                } else {
                    Capsule().strokeBorder(color.opacity(0.32))
                }
            }
            .accessibilityHint(info.targetLabel.map { "This release will be filed under the \($0) version, not the one you're viewing." }
                ?? "Blocked — no \(info.tier.tierShort) version exists to file this release under.")
    }
}

/// The icon-only Grab tile: tray-download (Grab) · warning triangle (Grab
/// anyway: rejected or blocklisted) · pulsing double chevron (Downloading).
struct SearchGrabTile: View {
    let title: String
    let anyway: Bool
    let blocklisted: Bool
    let downloading: Bool
    let onGrab: () -> Void

    var body: some View {
        let icon = downloading ? "chevron.down.2" : (anyway ? "exclamationmark.triangle" : "arrow.down.to.line")
        let color = downloading || !anyway ? Theme.grab : Theme.miss
        Button { if !downloading { onGrab() } } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .detailPulse(low: 0.6, high: 1, period: 1.8, active: downloading)
                .frame(width: 32, height: 30)
                .background {
                    if downloading {
                        RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            .fill(Theme.grab.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                .strokeBorder(Theme.grab.opacity(0.45)))
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, -6)
        .accessibilityLabel(downloading ? "Downloading \(title)"
            : blocklisted ? "Grab anyway (clears blocklist): \(title)"
            : anyway ? "Grab anyway: \(title)" : "Grab \(title)")
        .help(downloading ? "Downloading" : (blocklisted && anyway ? "Grab anyway · blocklisted" : (anyway ? "Grab anyway" : "Grab")))
    }
}
