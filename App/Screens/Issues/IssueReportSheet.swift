import SwiftUI
import FusionhaKit

/// Report an issue (web R6 `IssueModal`): what's wrong as chips, the version
/// (only when there are several), the part (series only) and a note. Report
/// files it and the sheet turns into the check flow; re-filing a report that
/// is already open shows where it stands.
struct IssueModal: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mediaItemId: Int
    let title: String
    let isSeries: Bool
    /// Season number → episode count, when known; otherwise numeric fields.
    let seasons: [Int: Int]?
    var year: Int? = nil
    var poster: String? = nil
    /// Reports a failure to the host's own toast (the item detail sheet).
    var onResult: ((String, Bool) -> Void)? = nil

    @State private var problem = "WONT_PLAY"
    @State private var versions: [IssueVersionRef] = []
    @State private var versionId: Int?
    @State private var picked = false
    @State private var needVersion = false
    @State private var scope = "item"
    @State private var season: Int?
    @State private var episode: Int?
    @State private var note = ""
    @State private var sending = false
    @State private var filed: (issueId: Int, reportId: Int, deduped: Bool)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let filed {
                        if filed.deduped {
                            Text("You’ve already reported this — here’s where it’s at.")
                                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        }
                        IssueCheckFlowView(issueId: filed.issueId, reportId: filed.reportId, isSeries: isSeries)
                        // The web's filed footer line.
                        Text("We’ll message you when something changes.")
                            .font(.system(size: 12)).foregroundStyle(Theme.dim)
                    } else {
                        form
                    }
                }
                .padding(16)
            }
            .background(Theme.panel)
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .task { await loadVersions() }
        // Kept across a fold / unfold when opened from a title (no-op elsewhere).
        .retainsDraft("issue.problem", $problem)
        .retainsDraft("issue.versionId", $versionId)
        .retainsDraft("issue.picked", $picked)
        .retainsDraft("issue.needVersion", $needVersion)
        .retainsDraft("issue.scope", $scope)
        .retainsDraft("issue.season", $season)
        .retainsDraft("issue.episode", $episode)
        .retainsDraft("issue.note", $note)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ActPoster(url: poster, title: title, size: .sm)
            VStack(alignment: .leading, spacing: 4) {
                (Text(title).fontWeight(.bold) + Text(verbatim: year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 16)).foregroundStyle(Theme.txt)
                HStack(spacing: 4) {
                    ForEach(Array(Set(versions.compactMap(\.tier))).sorted { $0.rawValue < $1.rawValue }, id: \.self) { ActTierChip(tier: $0) }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("What’s wrong?") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(IssueFormat.problems(series: isSeries), id: \.value) { p in problemChip(p) }
                }
            }
            if versions.count > 1 {
                section("Which version?", hint: versions.count == 2 ? "You can see both" : "You can see \(versions.count)") {
                    IssueVersionPicker(versions: versions, value: versionId) { versionId = $0; picked = true }
                    if needVersion && versionId == nil {
                        Text("Pick the version you mean.").font(.system(size: 12)).foregroundStyle(Theme.danger)
                    }
                }
            } else if versions.count == 1, let tier = versions[0].tier {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 12))
                    Text("This title has one version you can report on:")
                    ActTierChip(tier: tier)
                }
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            if isSeries { section("Which part?") { scopePicker } }
            section("Anything else?", hint: "Optional") {
                TextField("Tell us what you saw…", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(size: 14))
                    .padding(11)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            Text("You can report once per problem and version.").font(.system(size: 12)).foregroundStyle(Theme.dim)
        }
    }

    private func section<C: View>(_ label: String, hint: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Spacer()
                if let hint { Text(hint).font(.system(size: 12)).foregroundStyle(Theme.dim) }
            }
            content()
        }
    }

    private func problemChip(_ p: IssueFormat.Problem) -> some View {
        let on = problem == p.value
        return Button { problem = p.value } label: {
            HStack(spacing: 8) {
                Image(systemName: p.symbol).font(.system(size: 14))
                Text(p.label).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(on ? Theme.txt : Theme.mut)
            .padding(.horizontal, 12).frame(height: 44)
            .background(on ? Theme.i1.opacity(0.18) : Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? Theme.i1.opacity(0.6) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Which part?", selection: $scope) {
                Text("Whole show").tag("item")
                Text("A season").tag("season")
                Text("One episode").tag("episode")
            }
            .pickerStyle(.segmented)
            .onChange(of: scope) {
                if scope == "item" { season = nil; episode = nil }
                else if season == nil { season = seasons?.keys.sorted().first }
                if scope != "episode" { episode = nil }
            }
            if scope != "item" {
                HStack(spacing: 10) {
                    if let seasons, !seasons.isEmpty {
                        Picker("Season", selection: $season) {
                            Text("Select…").tag(Int?.none)
                            ForEach(seasons.keys.sorted(), id: \.self) { n in Text(n == 0 ? "Specials" : "Season \(n)").tag(Int?.some(n)) }
                        }
                        .onChange(of: season) { episode = nil }
                    } else {
                        TextField("Season", value: $season, format: .number).keyboardType(.numberPad)
                            .padding(10).background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if scope == "episode" {
                        if let seasons, let n = season, let count = seasons[n], count > 0 {
                            Picker("Episode", selection: $episode) {
                                Text("Select…").tag(Int?.none)
                                ForEach(1...count, id: \.self) { e in Text("Episode \(e)").tag(Int?.some(e)) }
                            }
                        } else {
                            TextField("Episode", value: $episode, format: .number).keyboardType(.numberPad)
                                .padding(10).background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    // MARK: Toolbar and filing

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if filed != nil {
            ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
        } else {
            ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await submit() } } label: {
                    ToolbarActionLabel(title: sending ? "Reporting…" : "Report", systemImage: "flag")
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.primary)
                .disabled(sending || !IssueFormat.scopeComplete(scope: isSeries ? scope : "item", season: season, episode: episode))
            }
        }
    }

    private func loadVersions() async {
        guard let client = model.client, let list = try? await client.reportableVersions(mediaItemId: mediaItemId) else { return }
        versions = list.filter { $0.id != nil && $0.tier != nil }
        if !picked { versionId = IssueFormat.defaultVersionId(versions) }
    }

    private func submit() async {
        guard let client = model.client else { return }
        sending = true
        defer { sending = false }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = isSeries ? scope : "item"
        do {
            let result = try await client.fileIssue(IssueReportBody(
                mediaItemId: mediaItemId, problem: problem, versionId: versionId, scope: s,
                season: s == "item" ? nil : season.map { max(0, $0) },
                episode: s == "episode" ? episode.map { max(1, $0) } : nil,
                description: text.isEmpty ? nil : text))
            if let report = IssueFormat.pickReport(result.issue.reports ?? [], problem: problem, versionId: versionId) {
                withAnimation(.snappy) { filed = (result.issue.id, report.id, result.issue.deduped == true) }
            } else {
                onResult?("Issue reported on \(title)", false)
                dismiss()
            }
        } catch {
            if (error as? APIError)?.code == "version_required" { needVersion = true }
            let message = ErrorCopy.message(for: error)
            if let onResult { onResult(message, true) } else { DiscoverToasts.shared.error("Could not report", error) }
        }
    }
}
