import SwiftUI
import FusionhaKit

/// A request's or a report's versions. v2 draws them as the monochrome
/// media badge (owner 2026-11-06/07): on disk solid, missing outlined,
/// downloading filling with the accent, held orange with "!", and a matching
/// pair joined. v1 keeps its tinted tier chips.
struct RequestTierBadges: View {
    let tiers: [QualityTier]
    var states: [QualityTier: EditionBadgeState] = [:]
    /// "1080p" / "2160p" after a single badge (the mock's "HD 1080p").
    var showsResolution = false

    var body: some View {
        #if V2
        HStack(spacing: 5) {
            EditionTicketPair(hd: state(.hd), uhd: state(.uhd), showsCount: false)
            if showsResolution, tiers.count == 1, let tier = tiers.first {
                Text(verbatim: RequestBadgeStates.resolution(tier))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mut)
            }
        }
        .fixedSize()
        #else
        HStack(spacing: 5) {
            ForEach(tiers, id: \.self) { ActTierChip(tier: $0) }
        }
        #endif
    }

    private func state(_ tier: QualityTier) -> EditionBadgeState? {
        tiers.contains(tier) ? (states[tier] ?? .missing) : nil
    }
}

extension RequestTierBadges {
    /// A request's versions in their live states.
    init(request: MediaRequest, showsResolution: Bool = false) {
        self.init(tiers: request.tiers, states: RequestBadgeStates.states(request), showsResolution: showsResolution)
    }
}

/// What each requested version's badge says, from the request's lifecycle.
enum RequestBadgeStates {
    static func states(_ request: MediaRequest) -> [QualityTier: EditionBadgeState] {
        var out: [QualityTier: EditionBadgeState] = [:]
        let lifecycle = request.lifecycle ?? []
        for tier in request.tiers {
            if let entry = lifecycle.first(where: { $0.tier == tier }) {
                out[tier] = state(entry)
            } else {
                out[tier] = request.status == "fulfilled" || request.status == "available" ? .onDisk : .missing
            }
        }
        return out
    }

    static func state(_ entry: RequestLifecycleEntry) -> EditionBadgeState {
        if entry.needsManualImport { return .held }
        switch entry.step {
        case .available: return .onDisk
        case .downloading: return .downloading(progress: entry.progressPct.map { Double($0) / 100 })
        default: return entry.importing ? .downloading(progress: 1) : .missing
        }
    }

    /// A reported copy: the version is on disk (the issue is about its file).
    static func onDisk(_ tiers: [QualityTier]) -> [QualityTier: EditionBadgeState] {
        var out: [QualityTier: EditionBadgeState] = [:]
        for tier in tiers { out[tier] = .onDisk }
        return out
    }

    static func resolution(_ tier: QualityTier) -> String {
        tier == .hd ? "1080p" : "2160p"
    }
}
