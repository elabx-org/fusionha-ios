import SwiftUI
import FusionhaKit

/// Admin, read-only (web `LetterboxdStatusDialog`, fusionha 0.4.213): what
/// one person's Letterboxd sources have done: the diary, checks, linked
/// count, failures, the outcome bar, each source with its status, and what a
/// Cloudflare block means with or without FlareSolverr. They control their
/// own sources; the admin controls the grant.
struct LetterboxdStatusView: View {
    let userId: Int
    let name: String
    let row: LetterboxdSummaryRow
    @Environment(AppModel.self) private var model
    @State private var read: LetterboxdAdmin?
    @State private var error: String?

    private var opens: Bool { SourceAdminCopy.letterboxdOpens(row.state) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    if let username = row.username { Text("@\(username)").font(.subheadline.weight(.semibold)) }
                    SourceStatePill(label: SourceAdminCopy.letterboxdOverall(row), tone: SourceAdminCopy.letterboxdTone(row.state))
                }
            } footer: {
                Text(opens ? "What the Letterboxd sources have done for this user. Read-only: they control their own sources; you control the grant."
                     : "\(name) hasn’t connected a Letterboxd profile or linked any source.")
            }
            if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
            if let read {
                facts(read)
                sources(read)
            } else if opens && error == nil {
                Section { ProgressView() }
            }
            Section {
                EmptyView()
            } footer: {
                Text("A film leaving a list or watchlist cancels nothing.")
            }
        }
        .navigationTitle("Letterboxd · \(name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { if opens { await load() } }
    }

    private func facts(_ read: LetterboxdAdmin) -> some View {
        let me = read.me
        let diaryOn = me.diary?.enabled == true
        let cantRead = row.state == "cant_read"
        let failures = read.consecutiveFailures ?? 0
        let linked = me.canLinkLists == true ? "\(me.linkedCount ?? 0) of \(me.maxLinkedLists ?? 5)" : "\(read.sources.count)"
        return Section {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    SourceStat(value: diaryOn ? "On" : "Off", label: "Diary")
                    SourceStat(value: SourceTime.ago(me.diary?.lastCheckedAt ?? row.lastCheckedAt), label: "Last checked")
                    SourceStat(value: cantRead ? "paused" : (diaryOn ? SourceTime.until(me.diary?.nextCheckAt) : "—"), label: "Next check")
                }
                GridRow {
                    SourceStat(value: "\(row.requestedCount)", label: "Requested")
                    SourceStat(value: linked, label: me.canLinkLists == true ? "Sources linked" : "Sources")
                    SourceStat(value: "\(failures)", label: "Consecutive failures")
                }
            }
            if cantRead {
                VStack(alignment: .leading, spacing: 3) {
                    (Text("Profile unreachable").bold() + Text(" · \(failures) consecutive failure\(failures == 1 ? "" : "s")"))
                    Text(SourceAdminCopy.profileErrorText(me.profileError, username: me.username ?? row.username ?? ""))
                        .foregroundStyle(Theme.mut)
                }
                .font(.footnote)
                .foregroundStyle(Theme.stuck)
            }
            SourceOutcomeBar(outcomes: read.outcomes)
        }
    }

    @ViewBuilder
    private func sources(_ read: LetterboxdAdmin) -> some View {
        if !read.sources.isEmpty {
            Section("Sources") {
                ForEach(read.sources) { s in sourceRow(s) }
            }
        }
        if read.sources.contains(where: { $0.status == "BLOCKED" }) {
            Section {
                (Text("Blocked by Cloudflare. ").bold() + Text(SourceAdminCopy.solverLine(configured: read.flaresolverrConfigured == true)))
                    .font(.footnote)
                    .foregroundStyle(Theme.stuck)
            }
        }
    }

    private func sourceRow(_ s: LetterboxdAdmin.Source) -> some View {
        let status = SourceAdminCopy.letterboxdStatus(s.status)
        let last = s.kind == "LETTERBOXD_CSV" ? "imported \(SourceTime.ago(s.lastCheckedAt))"
            : (s.lastCheckedAt == nil ? "not checked yet" : SourceTime.ago(s.lastCheckedAt))
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(SourceAdminCopy.letterboxdSourceName(s)).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 6)
                SourceStatePill(label: status.label, tone: status.tone)
            }
            Text([SourceAdminCopy.letterboxdKindWord(s.kind), s.lastError, "\(s.requestedCount) requested", last]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(Theme.mut)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            read = try await client.adminLetterboxd(userId: userId)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the Letterboxd status.")
        }
    }
}
