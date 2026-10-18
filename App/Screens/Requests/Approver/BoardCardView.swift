import SwiftUI
import FusionhaKit

/// One request on the board (web `BoardCard`): poster, title and year, tier
/// chips, the season scope and "Waiting for quota", the source; then what
/// the lead version is doing (a bar while downloading, "Needs a manual
/// import", "Waits for release · 12 d", the decline reason), every other
/// version's own state, the held guard or the rule that approved it, and
/// who asked beside who decided. The wash is the request's status.
struct BoardCardView: View {
    let request: MediaRequest
    let column: RequestBoard.Column

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }
    private var lifecycle: [RequestLifecycleEntry] { request.lifecycle ?? [] }

    var body: some View {
        let lead = RequestLifecycle.lead(lifecycle)
        let lagging = RequestLifecycle.lagging(lifecycle, lead: lead).filter { column != .available || $0.step != .available }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ActPoster(url: request.poster, title: title, size: .sm)
                VStack(alignment: .leading, spacing: 4) {
                    (Text(title).fontWeight(.semibold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 14.5)).foregroundStyle(Theme.txt).lineLimit(2)
                    HStack(spacing: 5) {
                        ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                        if let scope = RequestScope.chip(request) {
                            Text(scope).font(.system(size: 11, weight: .semibold).monospaced()).foregroundStyle(Theme.mut)
                        }
                        if request.status == "waiting" {
                            Label("Waiting for quota", systemImage: "clock").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.miss)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            leadLine(lead)
            ForEach(Array(lagging.enumerated()), id: \.offset) { _, e in
                Text("\(e.tier.chipLabel) · \(RequestLifecycle.versionWord(e))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(e.needsManualImport ? Theme.stuck : e.tier.color)
            }
            if let held = request.held {
                Label(held.label, systemImage: "hand.raised.fill").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.miss)
            }
            if request.approvedBy?.kind == "auto", let rule = request.approvedBy?.rule {
                Label("Auto-approved · \(rule)", systemImage: "bolt.fill").font(.system(size: 11.5)).foregroundStyle(Theme.done)
            }
            foot
        }
        .padding(12)
        .actWash(RequestLifecycle.wash(status: request.status, lifecycle: lifecycle).color, radius: 14, base: Theme.card)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func leadLine(_ lead: RequestLifecycleEntry?) -> some View {
        if let lead, lead.step == .downloading {
            if lead.needsManualImport {
                Text("Needs a manual import").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.stuck)
            } else if lead.importing {
                Text(RequestLifecycle.stepWord(lead).capitalizedFirst + "…").font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                HStack(spacing: 8) {
                    ActProgressBar(fraction: Double(lead.progressPct ?? 0) / 100, height: 4, shimmer: true)
                    if let pct = lead.progressPct {
                        Text("\(pct)%").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.grab)
                    }
                }
            }
        } else if column == .approved, let lead, lead.step != .available {
            Text(lead.step == .unreleased && lead.availableFrom != nil
                 ? "Waits for release · \(RequestLifecycle.daysUntil(lead.availableFrom!)) d"
                 : RequestLifecycle.stepWord(lead).capitalizedFirst)
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        } else if column == .declined, let reason = RequestLifecycle.reasonLabel(request.reason) {
            Text(reason).font(.system(size: 12)).foregroundStyle(Theme.danger)
        }
    }

    private var foot: some View {
        HStack(spacing: 6) {
            BoardRequesters(request: request)
            Spacer(minLength: 4)
            Group {
                if request.watch == true {
                    Label("Watching", systemImage: "eye").foregroundStyle(Theme.grab)
                } else if let by = request.approvedBy, by.kind != "auto" {
                    Text("by \(by.displayName ?? "an admin")").foregroundStyle(Theme.mut)
                } else if request.approvedBy?.kind == "auto", request.approvedBy?.rule == nil {
                    Text("Auto").foregroundStyle(Theme.done)
                } else if column == .pending {
                    Text(ActFmt.relative(request.requestedAt)).foregroundStyle(Theme.dim)
                }
            }
            .font(.system(size: 11.5, weight: .semibold))
            if column == .available, request.decidedAt != nil {
                Text(ActFmt.relative(request.decidedAt)).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            }
        }
        .lineLimit(1)
    }
}

/// Compact density: one line per request.
struct BoardCardCompact: View {
    let request: MediaRequest

    var body: some View {
        let title = request.title ?? "TMDB #\(request.tmdbId)"
        HStack(spacing: 8) {
            ActPoster(url: request.poster, title: title, size: .sm)
            Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            Spacer(minLength: 4)
            ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
            if request.status == "waiting" { Image(systemName: "clock").foregroundStyle(Theme.miss).font(.system(size: 11)) }
            BoardRequesters(request: request, avatarOnly: true)
        }
        .padding(8)
        .actWash(RequestLifecycle.wash(status: request.status, lifecycle: request.lifecycle ?? []).color, radius: 12, base: Theme.card)
        .accessibilityElement(children: .combine)
    }
}

/// Who asked: one person's chip, or initials stacked with "Sam +2".
struct BoardRequesters: View {
    let request: MediaRequest
    var avatarOnly = false

    var body: some View {
        let people = TriageFacts.people(request)
        if let first = people.first {
            if people.count == 1 && !avatarOnly {
                RequestPersonChip(name: first.displayName, prefix: nil)
            } else {
                HStack(spacing: 5) {
                    HStack(spacing: -6) {
                        ForEach(Array(people.prefix(3).enumerated()), id: \.offset) { _, p in
                            Text(String(p.displayName.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.onPrimary)
                                .frame(width: 18, height: 18)
                                .background(Theme.i1, in: Circle())
                                .overlay(Circle().strokeBorder(Theme.card, lineWidth: 1.5))
                        }
                    }
                    if !avatarOnly {
                        (Text(first.displayName).fontWeight(.semibold) + Text(" +\(people.count - 1)"))
                            .font(.system(size: 12)).foregroundStyle(Theme.txt)
                    }
                }
                .accessibilityLabel("Requested by " + people.map(\.displayName).joined(separator: ", "))
            }
        }
    }
}

extension String {
    /// "downloading" → "Downloading".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
