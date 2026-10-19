import SwiftUI
import FusionhaKit

/// One Board row (Final mock): poster, title and year, then what this stage
/// is about. Pending: tier · source · age. Approved: what it waits for.
/// Downloading: tier, percent and a bar. Available: who · landed when.
/// Declined: the reason. The requester is left out when the stage header
/// already says "all by …".
struct BoardStageRow: View {
    let request: MediaRequest
    let column: RequestBoard.Column
    var showRequester = true
    var compact = false

    private var lead: RequestLifecycleEntry? { RequestLifecycle.lead(request.lifecycle ?? []) }

    var body: some View {
        RequestsListRow(request: request, compact: compact) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    // Downloading shows the release quality ("WEBDL-1080p") in place of the tier (0.4.217).
                    if column == .downloading, let quality = lead?.quality, let tier = request.tiers.first {
                        Text(quality)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tier.color)
                            .padding(.horizontal, 6).frame(height: 20)
                            .background(tier.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else if let tier = request.tiers.first {
                        ActTierChip(tier: tier)
                    }
                    facts
                }
                if column == .downloading, let pct = lead?.progressPct, lead?.needsManualImport != true {
                    ActProgressBar(fraction: Double(pct) / 100, height: 4, fill: AnyShapeStyle(Theme.grab), shimmer: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var facts: some View {
        switch column {
        case .pending:
            Text(parts(RequestOrigin.word(request.source), ActFmt.relative(request.requestedAt)))
                .lineLimit(1)
            if request.status == "waiting" {
                Image(systemName: "clock").foregroundStyle(Theme.miss).accessibilityLabel("Waiting for quota")
            }
        case .approved:
            Text(parts(approvedWord)).lineLimit(1)
        case .downloading:
            if lead?.needsManualImport == true {
                Text("Needs a manual import").fontWeight(.semibold).foregroundStyle(Theme.stuck).lineLimit(1)
            } else if let pct = lead?.progressPct {
                Text(verbatim: "\(pct)%").fontWeight(.bold).monospacedDigit().foregroundStyle(Theme.grab)
                Text(parts(DownloadTimeLeft.text(lead?.etaSeconds))).lineLimit(1)
            } else {
                Text(parts(lead.map { RequestLifecycle.stepWord($0).capitalizedFirst })).lineLimit(1)
            }
        case .available:
            Text(parts("landed " + ActFmt.relative(request.availableAt ?? request.decidedAt))).lineLimit(1)
        case .declined:
            Text(parts(RequestLifecycle.reasonLabel(request.reason) ?? "Declined")).lineLimit(1)
        }
    }

    private var approvedWord: String? {
        guard let lead, lead.step != .available else { return nil }
        if lead.step == .unreleased, let from = lead.availableFrom {
            return "Waits for release · \(RequestLifecycle.daysUntil(from)) d"
        }
        return RequestLifecycle.stepWord(lead).capitalizedFirst
    }

    /// The requester (unless the header names them), then the stage's facts.
    private func parts(_ facts: String?...) -> String {
        let who = showRequester ? request.requester?.displayName : nil
        return ([who] + facts).compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
