import SwiftUI
import FusionhaKit

/// A version with no file that the server proved out early: what was
/// spotted, then the releases behind the proof (web `EarlySpottedList`):
/// the release name in mono, then "7 indexers · 109.2 GB". The summary line
/// stays when the evidence was pruned; the list just goes.
struct V2EarlySpottedList: View {
    @Environment(\.pagePalette) private var page
    let early: EarlyRelease

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let spotted = early.spotted ?? []
        VStack(alignment: .leading, spacing: 8) {
            Text("\(Text(EarlyReleaseCopy.headline(early) + ".").bold().foregroundStyle(ink)) \(EarlyReleaseCopy.versionSummary(early))")
                .font(.system(size: 13))
                .foregroundStyle(ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            if !spotted.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Spotted early")
                        .font(.system(size: 11.5, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.3)
                        .foregroundStyle(muted)
                        .padding(.bottom, 4)
                    ForEach(spotted) { release in
                        row(release)
                        if release.id != spotted.last?.id {
                            Rectangle().fill(muted.opacity(0.2)).frame(height: 0.5)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Spotted releases")
            }
        }
    }

    private func row(_ release: EarlySpotted) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(release.title)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text([EarlyReleaseCopy.indexers(release), release.size.map { DetailText.bytes($0) }]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(muted)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
