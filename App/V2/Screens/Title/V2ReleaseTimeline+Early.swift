import SwiftUI
import FusionhaKit

// MARK: - Out early (owner-approved mock, 2026-11-08)
//
// A step the server proved out before its listed date reads as reached:
// a filled disc, "Out early · 7 Nov" and the listed date struck through.
// The evidence sentence sits under the steps, worded as the web's
// `early-release-model.ts`. Monochrome, like the media badges: nothing here
// is downloading or needs the owner, so no accent.
extension V2ReleaseTimeline {
    @ViewBuilder
    func earlyLines(_ step: Step, early: EarlyRelease) -> some View {
        Text(EarlyReleaseCopy.chip(early))
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(page?.ink ?? Theme.txt)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        HStack(spacing: 4) {
            Text(step.date.formatted(.dateTime.month(.abbreviated).day().year()))
                .strikethrough()
            Text("listed")
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// "Out early · 25 releases. Spotted on 11 indexers · 18 groups, …".
    func evidence(_ early: EarlyRelease, steps: [Step]) -> some View {
        let listed = steps.first { $0.kind == "digital" }?.iso
        return VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill((page?.inkMuted ?? Theme.mut).opacity(0.3))
                .frame(height: 0.5)
            Text("\(Text(EarlyReleaseCopy.headline(early) + ".").bold().foregroundStyle(page?.ink ?? Theme.txt)) \(EarlyReleaseCopy.evidence(early, listed: listed))")
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle((page?.ink ?? Theme.txt).opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}
