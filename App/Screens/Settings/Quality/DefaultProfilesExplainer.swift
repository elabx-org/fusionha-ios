import SwiftUI
import FusionhaKit

/// A cell's applicability tag ("Add + Import" / "Add flow"): a tinted pill.
struct DefaultProfilesTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .fixedSize()
    }
}

/// How Library Import resolves a profile from the matrix (web `.mapRow`):
/// three example roots, each read by kind + tier.
struct DefaultProfilesMappingExample: View {
    private struct Example: Identifiable {
        let path: String
        let tier: QualityTier?
        let profile: String
        var id: String { path }
    }

    private let examples = [
        Example(path: "/mnt/plex/tv-4k", tier: .uhd, profile: "UHD-Series"),
        Example(path: "/data/anime", tier: .hd, profile: "HD-1080p-Anime"),
        Example(path: "/new-movies-4k", tier: nil, profile: "UHD-Movies"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Library Import reads these by kind + tier — the cell's root folder is ignored (import adopts the folder you point it at)")
            } icon: {
                Image(systemName: "arrow.down.to.line")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(examples) { example in
                row(example)
            }
        }
        .padding(.vertical, 4)
    }

    private func row(_ example: Example) -> some View {
        HStack(spacing: 8) {
            Text(example.path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .truncationMode(.middle)
            if let tier = example.tier {
                DefaultProfilesTag(text: tier == .uhd ? "4K" : "HD", color: tier.color)
            } else {
                DefaultProfilesTag(text: "new root", color: Theme.mut)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
            Text(example.profile)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The legend for the per-cell tags (web `.legend`).
struct DefaultProfilesTagLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            key(DefaultProfilesTag(text: "Add + Import", color: Theme.i2),
                "used everywhere a title/version is created")
            key(DefaultProfilesTag(text: "Add flow", color: Theme.edition),
                "only the Add dialog (Import uses the folder it scans)")
        }
        .padding(.vertical, 4)
    }

    private func key(_ tag: DefaultProfilesTag, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            tag
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
