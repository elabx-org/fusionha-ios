import SwiftUI
import FusionhaKit

/// `HeldWhyDetail`: claimed vs probed quality, what's on disk, the verdict.
struct HeldWhy: View {
    let detail: HeldDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let headline = HeldCopy.headline(detail, reason: nil) {
                Text(headline).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.miss)
                    .padding(.bottom, 2)
            }
            if let claimed = detail.claimedQuality ?? detail.probedQuality {
                if detail.mislabeled == true, let probed = detail.probedQuality {
                    let res = detail.probedResolution.map { " (\($0.w)×\($0.h))" } ?? ""
                    line("Release claimed:", "\(ActFmt.quality(claimed)) mislabeled — actually \(ActFmt.quality(probed))\(res)")
                } else {
                    line("Release claimed:", ActFmt.quality(claimed))
                }
            }
            if let current = detail.currentQuality {
                let extra = [detail.currentGroup, detail.currentCf.map { "CF \($0)" }].compactMap { $0 }.joined(separator: ", ")
                line("On disk:", ActFmt.quality(current) + (extra.isEmpty ? "" : " (\(extra))"))
            }
            if let verdict = detail.verdict {
                line("Verdict:", "not an upgrade (\(HeldCopy.verdictLabel(verdict)))")
            }
        }
        .padding(8)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
    }

    private func line(_ k: String, _ v: String) -> some View {
        (Text(k + " ").foregroundColor(Theme.dim) + Text(v).foregroundColor(Theme.txt))
            .font(.system(size: 11))
    }
}
