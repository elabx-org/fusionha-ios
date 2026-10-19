import SwiftUI
import FusionhaKit

/// What a trail's candidates are judged against: the run title's profile per
/// tier and how many releases the pass considered (web `Trail.tsx`).
struct TrailContext {
    var profiles: [QualityTier: TrailProfile] = [:]
    var considered = 0

    func profile(for c: RunCandidate) -> TrailProfile? { profiles[TrailModel.tier(forQuality: c.quality)] }
}

private struct TrailContextKey: EnvironmentKey {
    static let defaultValue = TrailContext()
}

extension EnvironmentValues {
    var trailContext: TrailContext {
        get { self[TrailContextKey.self] }
        set { self[TrailContextKey.self] = newValue }
    }
}

/// One candidate line (`.tline`): dot, release, group, size, ×N, why. Tapping
/// it opens the CF-score breakdown and the decision chain (`CandidateBreakdown`).
struct CandidateLine: View {
    let row: TasksLogic.DedupRow
    @Environment(\.trailContext) private var context
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false

    var body: some View {
        let c = row.rep
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) { line(c) }
                .buttonStyle(.plain)
                .accessibilityHint(open ? "Hides the score breakdown" : "Shows the score breakdown")
                .accessibilityAddTraits(open ? .isSelected : [])
            if open {
                CandidateBreakdownView(candidate: c, profile: context.profile(for: c), considered: context.considered)
                    .padding(.leading, 17)
                    .padding(.bottom, 8)
                    .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1).mask(
                HStack(spacing: 3) { ForEach(0..<80, id: \.self) { _ in Rectangle().frame(width: 4) } })
        }
    }

    private func toggle() {
        if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.22)) { open.toggle() } }
    }

    private func line(_ c: RunCandidate) -> some View {
        let dot: Color = c.action == "GRAB" ? Theme.done : (c.action == "UPGRADE" ? Theme.grab : (c.action == "REJECT" ? Theme.miss : Theme.dim))
        let whyColor: Color = (c.action == "GRAB" || c.action == "UPGRADE") ? Theme.done : (c.action == "REJECT" ? Theme.miss : Theme.mut)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(c.releaseTitle).foregroundStyle(Theme.txt).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let group = c.releaseGroup { Text(group).foregroundStyle(Theme.edition).lineLimit(1).fixedSize() }
                if let size = c.size { Text(ActFmt.bytes(size)).foregroundStyle(Theme.dim).fixedSize() }
                if row.count > 1 || row.indexers > 1 {
                    Text("×\(row.count)\(row.indexers > 1 ? " · \(row.indexers) indexers" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                        .fixedSize()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                    .rotationEffect(.degrees(open ? 90 : 0))
            }
            Text(why(c))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(whyColor)
                .lineLimit(2)
                .padding(.leading, 17)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func why(_ c: RunCandidate) -> String {
        if let score = c.cfScore, score != 0 {
            let signed = TrailModel.signed(score)
            return c.reason.isEmpty ? signed : "\(c.reason) · \(signed)"
        }
        return c.reason.isEmpty ? "—" : c.reason
    }
}
