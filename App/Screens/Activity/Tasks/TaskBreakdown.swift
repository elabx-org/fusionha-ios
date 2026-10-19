import SwiftUI
import FusionhaKit

/// The expanded breakdown for one candidate (web `CandidateBreakdown`): (A) the
/// custom-format score composition and the upgrade-until track, (B) the
/// decision chain and verdict. A historical row with no captured `matched`
/// recomputes it once from the CF tester against the edition's profile.
struct CandidateBreakdownView: View {
    let candidate: RunCandidate
    let profile: TrailProfile?
    let considered: Int
    @Environment(AppModel.self) private var model
    @State private var fallback: CFTestResult?
    @State private var testing = false
    @State private var testFailed = false

    /// A chart ramp (violet + slate), never a status colour; negatives use danger.
    static var hues: [Color] { [Theme.i1, Theme.i2, Theme.i1.opacity(0.62), Theme.i2.opacity(0.6), Theme.dim] }

    private var stored: [CFTestMatch] { candidate.matched ?? [] }
    private var matched: [CFTestMatch] { stored.isEmpty ? (fallback?.matched ?? []) : stored }
    private var total: Int { candidate.cfScore ?? fallback?.total ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            scoreSection
            chainSection
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
        .task { await recomputeIfNeeded() }
    }

    // MARK: (A) Custom format score

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            title("Custom format score")
            if testing { note("Recomputing the breakdown…") }
            if testFailed { note("The breakdown could not be recomputed.") }
            if matched.isEmpty {
                if !testing && !testFailed { note("No custom formats matched this release.") }
            } else {
                let maxAbs = max(1, matched.map { abs($0.score) }.max() ?? 1)
                ForEach(Array(matched.enumerated()), id: \.offset) { index, m in
                    HStack(spacing: 8) {
                        Text(m.name).font(.system(size: 12)).foregroundStyle(Theme.txt).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        GeometryReader { geo in
                            Capsule().fill(m.score < 0 ? Theme.danger : Self.hues[index % Self.hues.count])
                                .frame(width: geo.size.width * CGFloat(abs(m.score)) / CGFloat(maxAbs))
                        }
                        .frame(width: 70, height: 5)
                        .background(Theme.panel2, in: Capsule())
                        Text(TrailModel.signed(m.score))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(m.score < 0 ? Theme.danger : Theme.txt)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                }
            }
            HStack {
                Text("Total").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                Text(TrailModel.signed(total)).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.txt)
            }
            if recomputed { note("Recomputed with current formats.") }
            if let profile, let track = TrailModel.track(total: total, profile: profile) {
                upgradeTrack(track, profile: profile)
            }
        }
    }

    private var recomputed: Bool {
        guard stored.isEmpty, let fallback else { return false }
        return fallback.total != (candidate.cfScore ?? fallback.total)
    }

    private func upgradeTrack(_ track: (totalPct: Int, floorPct: Int), profile: TrailProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panel2)
                    Capsule().fill(Theme.i1).frame(width: geo.size.width * CGFloat(track.totalPct) / 100)
                    Rectangle().fill(Theme.txt).frame(width: 2, height: 9)
                        .offset(x: geo.size.width * CGFloat(track.floorPct) / 100 - 1)
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(total) of \(profile.ceiling ?? 0) upgrade-until")
                Spacer(minLength: 0)
                Text("floor \(profile.floor)")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Theme.dim)
        }
        .padding(.top, 2)
    }

    // MARK: (B) Decision chain

    private var chainSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            title("Why it was \(TrailModel.verdictLabel(candidate.action).lowercased())")
            ForEach(TrailModel.chain(candidate, profile: profile, considered: considered)) { step in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(step.mark).font(.system(size: 12, weight: .bold)).foregroundStyle(color(step.state))
                        .frame(width: 12)
                    Text(step.text).font(.system(size: 12)).foregroundStyle(Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 6) {
                let tone = verdictColor
                Text(TrailModel.verdictLabel(candidate.action))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tone)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(tone.opacity(0.14), in: Capsule())
                if let q = candidate.quality {
                    Text(DetailText.quality(q)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                }
            }
            Text(candidate.reason.isEmpty ? "—" : candidate.reason)
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var verdictColor: Color {
        switch candidate.action {
        case "GRAB": return Theme.done
        case "UPGRADE": return Theme.grab
        case "REJECT": return Theme.miss
        default: return Theme.mut
        }
    }

    private func color(_ state: TrailModel.ChainStep.State) -> Color {
        switch state {
        case .ok: return Theme.done
        case .up: return Theme.grab
        case .no: return Theme.miss
        case .info: return Theme.dim
        }
    }

    private func title(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.5).foregroundStyle(Theme.dim)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.mut)
    }

    /// Lazy fallback: once per open, only when nothing was captured.
    private func recomputeIfNeeded() async {
        guard stored.isEmpty, fallback == nil, !testing, let profile, let client = model.client else { return }
        testing = true
        defer { testing = false }
        do {
            let r = try await client.testCustomFormats(titles: [candidate.releaseTitle], qualityProfileId: profile.id,
                                                       originalLanguage: profile.originalLanguage)
            fallback = r.results.first
        } catch {
            testFailed = true
        }
    }
}
