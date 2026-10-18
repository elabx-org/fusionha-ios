import SwiftUI
import FusionhaKit

/// Admin, read-only (web `WatchlistStatusDialog`, fusionha 0.4.209): what one
/// person's Plex watchlist & lists have done: the facts, the outcome bar,
/// errors, whether a Plex sign-in is saved (never the token), each source
/// and the latest items. An admin can pause or resume it here
/// (`PATCH /users/{id}/plex-watchlist`; the web leaves that to the API).
struct PlexWatchlistStatusView: View {
    let userId: Int
    let name: String
    let row: PlexWatchlistSummaryRow
    @Environment(AppModel.self) private var model
    @State private var read: PlexWatchlistAdmin?
    @State private var error: String?
    @State private var working = false

    private var opens: Bool { SourceAdminCopy.plexChip(row.state).opens }

    var body: some View {
        Form {
            Section {
                SourceStatePill(label: SourceAdminCopy.plexChipLabel(row), tone: SourceAdminCopy.plexChip(row.state).tone)
            } footer: {
                Text(SourceAdminCopy.plexDescription(row.state))
            }
            if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
            if let read {
                facts(read)
                sources(read)
                recent(read)
                if model.me?.isAdmin == true { pauseSection(read) }
            } else if opens && error == nil {
                Section { ProgressView() }
            }
            Section {
                EmptyView()
            } footer: {
                Text("A title leaving their watchlist cancels nothing.")
            }
        }
        .navigationTitle("Plex watchlist · \(name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { if opens { await load() } }
    }

    private func facts(_ read: PlexWatchlistAdmin) -> some View {
        let enabled = (read.sources ?? []).contains(where: \.enabled)
        let next = SourceAdminCopy.plexNextCheckWord(read) ?? (enabled ? SourceTime.until(read.nextCheckAt) : "—")
        return Section {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    SourceStat(value: enabled ? "Yes" : "No", label: "Enabled")
                    SourceStat(value: SourceTime.ago(read.lastCheckedAt), label: "Last synced")
                    SourceStat(value: next, label: "Next check")
                }
                GridRow {
                    SourceStat(value: "\(read.outcomes?.total ?? 0)", label: "Items seen")
                    SourceStat(value: "\(read.requestedTotal ?? 0)", label: "Requested")
                    SourceStat(value: "\(read.outcomes?["WAITING"] ?? 0)", label: "Waiting (limit)")
                }
            }
            SourceOutcomeBar(outcomes: read.outcomes)
            errors(read)
            LabeledContent {
                Text(read.plexTokenSet == true ? "Saved" : "Not saved")
                    .foregroundStyle(read.plexTokenSet == true ? Theme.done : Theme.stuck)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved Plex sign-in")
                    Text("Stored encrypted only while the feature is on. The token itself is never shown.")
                        .font(.caption).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    @ViewBuilder
    private func errors(_ read: PlexWatchlistAdmin) -> some View {
        let failures = read.consecutiveFailures ?? 0
        if let title = SourceAdminCopy.plexErrorTitle(read) {
            VStack(alignment: .leading, spacing: 3) {
                (Text(title).bold() + Text(" · \(failures) consecutive failure\(failures == 1 ? "" : "s")"))
                if let last = read.lastError { Text(last).foregroundStyle(Theme.mut) }
            }
            .font(.footnote)
            .foregroundStyle(Theme.stuck)
        } else {
            LabeledContent("Errors") { Text("None").foregroundStyle(Theme.done) }
        }
    }

    @ViewBuilder
    private func sources(_ read: PlexWatchlistAdmin) -> some View {
        let rows = read.sources ?? []
        if !rows.isEmpty {
            Section("Sources") {
                ForEach(rows, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(s.name).font(.subheadline.weight(.semibold)).foregroundStyle(s.enabled ? Theme.txt : Theme.mut)
                            Spacer()
                            Text("\(s.requestedCount) requested").font(.caption).foregroundStyle(Theme.mut)
                        }
                        Text(sourceLine(s)).font(.caption).foregroundStyle((s.errorCount ?? 0) > 0 ? Theme.stuck : Theme.mut)
                        if s.truncated == true {
                            Text("Too long to read in full: only the first part is checked").font(.caption).foregroundStyle(Theme.miss)
                        }
                    }
                }
            }
        }
    }

    private func sourceLine(_ s: PlexWatchlistAdmin.Source) -> String {
        var parts: [String] = []
        if s.kind == "PLEX_LIST" { parts.append(["Plex list", SourceAdminCopy.visibility(s.visibility)].compactMap { $0 }.joined(separator: " · ")) }
        if let n = s.errorCount, n > 0 { parts.append("\(n) error\(n == 1 ? "" : "s")" + (s.lastError.map { " · \($0)" } ?? "")) }
        parts.append("checked \(SourceTime.ago(s.lastCheckedAt))")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func recent(_ read: PlexWatchlistAdmin) -> some View {
        let rows = read.recent ?? []
        if !rows.isEmpty {
            Section("Latest items") {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 8) {
                        (Text(r.title ?? "Unknown title") + Text(r.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                            .font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                        SourceStatePill(label: SourceAdminCopy.outcomeLabel(r.outcome), tone: SourceAdminCopy.outcomeTone(r.outcome))
                        Text(SourceTime.ago(r.firstSeenAt)).font(.caption).foregroundStyle(Theme.dim)
                    }
                }
            }
        }
    }

    private func pauseSection(_ read: PlexWatchlistAdmin) -> some View {
        let paused = read.paused == true
        return Section {
            Button(paused ? "Resume automatic requests" : "Pause automatic requests",
                   systemImage: paused ? "play.circle" : "pause.circle") {
                Task { await setPaused(!paused) }
            }
            .disabled(working)
        } footer: {
            Text(paused ? "Resuming lets the watchlist be read again; they may need one more Plex sign-in."
                 : "Pausing stops every Plex check for them and clears their saved Plex sign-in. Requests already made stay.")
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            read = try await client.adminPlexWatchlist(userId: userId)
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the watchlist status.")
        }
    }

    private func setPaused(_ paused: Bool) async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await client.setPlexWatchlistPaused(userId: userId, paused)
            await load()
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t change it.")
        }
    }
}
