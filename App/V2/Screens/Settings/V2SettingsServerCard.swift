import SwiftUI
import FusionhaKit

/// The server card that heads Settings (mock settings-v2.js `header`): the
/// server's address, version, database and uptime; a health line (online,
/// indexers, clients, warnings in orange); storage as one-ink capsule; and
/// the health warnings, which open in place.
struct V2SettingsServerCard: View {
    let server: String
    let summary: V2SettingsSummary
    let storage: V2SettingsStorage?
    @State private var showsWarnings = false
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
                .padding(.horizontal, 16)
                .padding(.top, 15)
            healthLine
                .padding(.horizontal, 16)
                .padding(.top, 12)
            if let storage {
                VStack(alignment: .leading, spacing: 8) {
                    StorageCapsule(segments: storage.segments, capacity: storage.capacity)
                    Text("\(Format.bytes(storage.free)) free of \(Format.bytes(storage.capacity))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            Color.clear.frame(height: 14)
            if !summary.warnings.isEmpty { warnings }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 24) }
    }

    private var identity: some View {
        HStack(spacing: 13) {
            // The fusionha mark, as on Home's heading.
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(server)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
        }
    }

    private var meta: String {
        let parts = [summary.version.map { "fusionha \($0)" }, summary.backendLabel, summary.uptimeLabel]
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? "Checking the server…" : text
    }

    private var healthLine: some View {
        let online = summary.online
        let dot: Color = online == true ? Theme.done : online == false ? Theme.danger : Theme.dim
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(online == true ? "Online" : online == false ? "Offline" : "Connecting…")
                .foregroundStyle(page?.ink ?? Theme.txt)
            if let n = summary.indexerCount { Text("· \(n) indexers").foregroundStyle(muted) }
            if let n = summary.clientCount { Text("· \(n) clients").foregroundStyle(muted) }
            if !summary.warnings.isEmpty {
                Text("· \(summary.warnings.count) \(summary.warnings.count == 1 ? "warning" : "warnings")")
                    .foregroundStyle(Theme.stuckText)
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .accessibilityElement(children: .combine)
    }

    /// The warnings row: a count and the first messages; tap lists them all.
    private var warnings: some View {
        VStack(alignment: .leading, spacing: 0) {
            ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight)
                .frame(height: EditionChip.hairline(displayScale))
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { showsWarnings.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.stuck.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(summary.warnings.count) health \(summary.warnings.count == 1 ? "warning" : "warnings")")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(page?.ink ?? Theme.txt)
                        if !showsWarnings {
                            Text(summary.warnings.map(\.message).joined(separator: " · "))
                                .font(.footnote)
                                .foregroundStyle(muted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(showsWarnings ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsWarnings ? "Expanded" : "Collapsed")
            if showsWarnings {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summary.warnings, id: \.self) { check in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.message)
                                .font(.subheadline)
                                .foregroundStyle(page?.ink ?? Theme.txt)
                                .fixedSize(horizontal: false, vertical: true)
                            if let source = check.source, !source.isEmpty {
                                Text(source).font(.caption).foregroundStyle(muted)
                            }
                        }
                    }
                }
                .padding(.leading, 58)
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }
}
