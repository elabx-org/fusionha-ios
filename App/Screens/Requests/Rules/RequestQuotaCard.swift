import SwiftUI
import FusionhaKit

/// "Weekly request quota" (web A3 `QuotaCard` + `QuotaDefault`): the default
/// per user, per week (roles and users can override it), then everyone's week
/// with whoever is at their limit first.
struct RequestQuotaCard: View {
    let canManage: Bool
    @Environment(AppModel.self) private var model
    @State private var quotas: [UserQuota] = []
    @State private var defaultQuota: Int?
    @State private var loaded = false
    @State private var saving = false

    private var isAdmin: Bool { model.me?.isAdmin ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WEEKLY REQUEST QUOTA").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            Text("Per user, per week. Roles and users can override it.").font(.footnote).foregroundStyle(Theme.mut)
            HStack {
                Text("Default").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Spacer()
                Menu {
                    Button("Unlimited") { Task { await setDefault(nil) } }
                    ForEach([1, 2, 3, 5, 10, 20, 50], id: \.self) { n in
                        Button("\(n) a week") { Task { await setDefault(n) } }
                    }
                } label: {
                    GlassMenuLabel(title: defaultQuota.map { "\($0) a week" } ?? "Unlimited")
                }
                .disabled(!isAdmin || saving)
            }
            if !isAdmin { Text("Only an admin can change the default quota").font(.caption).foregroundStyle(Theme.dim) }
            ForEach(UserQuota.sorted(quotas)) { q in quotaRow(q) }
            if loaded && quotas.isEmpty { Text("No one has requested yet.").font(.subheadline).foregroundStyle(Theme.mut) }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .task { await load() }
    }

    private func quotaRow(_ q: UserQuota) -> some View {
        let fraction = q.limit.map { $0 > 0 ? min(1, Double(q.used) / Double($0)) : 1 } ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(q.person.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer()
                Text(q.limit.map { "\(q.used) of \($0)" } ?? "\(q.used) · Unlimited")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(q.atLimit == true ? Theme.miss : Theme.txt)
            }
            if q.limit != nil {
                ProgressView(value: fraction).tint(q.atLimit == true ? Theme.miss : Theme.i1)
            }
            Text([q.sourceLabel, (q.waiting ?? 0) > 0 ? "\(q.waiting ?? 0) waiting for quota" : nil].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard let client = model.client else { return }
        quotas = (try? await client.requestQuotas()) ?? quotas
        if let settings = try? await client.settings() {
            defaultQuota = settings["request_default_quota_per_week"]?.int
        }
        loaded = true
    }

    private func setDefault(_ n: Int?) async {
        guard let client = model.client else { return }
        saving = true
        defer { saving = false }
        do {
            _ = try await client.updateSettings(["request_default_quota_per_week": n.map { .number(Double($0)) } ?? .null])
            defaultQuota = n
            quotas = (try? await client.requestQuotas()) ?? quotas
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Couldn’t change the quota", variant: .error)
        }
    }
}

/// "Recently auto-approved" (web `AutoApprovedStrip`): the last 24 hours, newest first.
struct RequestAutoApprovedStrip: View {
    @Environment(AppModel.self) private var model
    @State private var requests: [MediaRequest] = []
    @State private var loaded = false
    @State private var thread: MediaRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENTLY AUTO-APPROVED").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            if loaded && requests.isEmpty {
                Text("Nothing was approved automatically in the last 24 hours.").font(.subheadline).foregroundStyle(Theme.mut)
            }
            ForEach(requests) { r in
                Button { thread = r } label: {
                    HStack(spacing: 10) {
                        ActPoster(url: r.poster, title: r.title ?? "", size: .sm)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title ?? "Request").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                            // Who, from where, why: "kids-tv · Plex list · Kids · Kids list rule".
                            Text([r.requester?.displayName,
                                  RequestSourceWords.isAutomatic(r.source?.kind) ? RequestSourceWords.phrase(r.source, mine: false) : nil,
                                  r.approvedBy?.rule]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                                .lineLimit(2).truncationMode(.middle)
                        }
                        Spacer(minLength: 0)
                        // Stacked, so two chips don't squeeze the reason off the line.
                        VStack(alignment: .trailing, spacing: 4) { ForEach(r.tiers, id: \.self) { ActTierChip(tier: $0) } }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .task {
            guard let client = model.client else { return }
            requests = (try? await client.autoApprovedRequests()) ?? []
            loaded = true
        }
        .sheet(item: $thread) { r in RequestThreadSheet(request: r) {} }
    }
}
