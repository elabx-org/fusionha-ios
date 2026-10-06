import SwiftUI
import FusionhaKit

// Issues: the Issues tab for `issues.manage` holders (`IssuesPanel.tsx`), the
// Resolve dialog, and the "Report an issue" modal (`IssueModal.tsx`).

struct IssuesPanel: View {
    @Environment(AppModel.self) private var model
    @State private var status = "open"
    @State private var issues: [MediaIssue] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var resolving: MediaIssue?
    @State private var version = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DiscoverSegmented(options: [("open", "Open"), ("resolved", "Resolved")], selection: $status, fullTrack: true)
            if !loaded {
                DiscoverEmptyState(message: "Loading issues…")
            } else if failed {
                DiscoverEmptyState(message: "Could not load issues.")
            } else if issues.isEmpty {
                DiscoverEmptyState(message: status == "open" ? "No open issues." : "No resolved issues yet.")
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                        IssueRow(issue: issue, title: title(for: issue),
                                 onResolve: { resolving = issue },
                                 onDelete: { Task { await delete(issue) } })
                            .discoverReveal(index: index)
                    }
                }
            }
        }
        .task(id: "\(status)|\(version)") { await load() }
        .sheet(item: $resolving) { issue in
            ResolveDialog(issue: issue) { version += 1 }
        }
    }

    private func title(for issue: MediaIssue) -> String {
        model.library.first { $0.id == issue.mediaItemId }?.title ?? "Item #\(issue.mediaItemId)"
    }

    private func load() async {
        guard let client = model.client else { return }
        if !model.libraryLoaded { await model.loadLibrary() }
        do {
            issues = try await client.issues(status: status)
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
    }

    private func delete(_ issue: MediaIssue) async {
        do {
            try await model.client?.deleteIssue(id: issue.id)
            version += 1
        } catch {
            DiscoverToasts.shared.error("Could not delete issue", error)
        }
    }
}

private struct IssueRow: View {
    let issue: MediaIssue
    let title: String
    let onResolve: () -> Void
    let onDelete: () -> Void

    private var resolved: Bool { issue.status == "resolved" }

    var body: some View {
        let color = resolved ? Theme.done : Theme.stuck
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                PreviewFlow(spacing: 6) {
                    RequestStatusPill(label: resolved ? "Resolved" : "Open", color: color)
                    Text(issue.typeLabel)
                    Text("·")
                    Text(issue.scopeLabel)
                    Text("·")
                    Text("Reported by user #\(issue.reporterUserId)")
                    if !DiscoverRelativeTime.string(issue.createdAt).isEmpty {
                        Text("·")
                        Text(DiscoverRelativeTime.string(issue.createdAt))
                    }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .padding(.top, 3)
                if let description = issue.description, !description.isEmpty {
                    Text("“\(description)”").font(.system(size: 12)).italic().foregroundStyle(Theme.mut)
                        .padding(.top, 5)
                }
                if resolved, let comment = issue.comment, !comment.isEmpty {
                    Text("Resolution: “\(comment)”").font(.system(size: 12)).italic().foregroundStyle(Theme.done)
                        .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if !resolved {
                    Button("Resolve", action: onResolve).buttonStyle(.discover(.primary))
                }
                DiscoverIconButton(systemImage: "trash", label: "Delete issue", tint: Theme.danger, action: onDelete)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .statusWash(color)
    }
}

private struct ResolveDialog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let issue: MediaIssue
    let onDone: () -> Void
    @State private var comment = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Comment (optional)", text: $comment, axis: .vertical).lineLimit(2...4)
                } footer: {
                    Text("An optional note for the reporter's record.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("Resolve issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Resolving…" : "Resolve") { Task { await submit() } }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.done)
                        .disabled(sending)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    private func submit() async {
        sending = true
        defer { sending = false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await model.client?.resolveIssue(id: issue.id, comment: trimmed.isEmpty ? nil : trimmed)
            DiscoverToasts.shared.show(.success, "Issue resolved")
            onDone()
            dismiss()
        } catch {
            DiscoverToasts.shared.error("Could not resolve issue", error)
        }
    }
}

/// "Report an issue" (`IssueModal.tsx`), also usable from item detail.
struct IssueModal: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mediaItemId: Int
    let title: String
    let isSeries: Bool
    /// Season number → episode count, when known; otherwise numeric fields.
    let seasons: [Int: Int]?
    /// Reports the outcome (message, failed) to the host's own toast, e.g. the
    /// item detail sheet; Discover's shared toast otherwise.
    var onResult: ((String, Bool) -> Void)? = nil

    @State private var type: IssueType = .playback
    @State private var scope = "item"
    @State private var season: Int?
    @State private var episode: Int?
    @State private var description = ""
    @State private var sending = false

    private var ready: Bool {
        switch scope {
        case "season": return season != nil
        case "episode": return season != nil && episode != nil
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    (Text("Tell us what's wrong with ") + Text(title).bold() + Text(" — an admin will take a look."))
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .listRowBackground(Color.clear)
                }
                Section {
                    Picker("What's wrong?", selection: $type) {
                        ForEach(IssueType.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if isSeries {
                        Picker("Where?", selection: $scope) {
                            Text("Whole series").tag("item")
                            Text("One season").tag("season")
                            Text("One episode").tag("episode")
                        }
                        if scope != "item" {
                            seasonField
                            if scope == "episode" { episodeField }
                        }
                    }
                }
                .listRowBackground(Theme.card)
                Section("Description · optional") {
                    TextField("What happened? Any details help.", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("Report an issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sending ? "Reporting…" : "Report issue") { Task { await submit() } }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.danger)
                        .disabled(sending || !ready)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    @ViewBuilder
    private var seasonField: some View {
        if let seasons, !seasons.isEmpty {
            Picker("Season", selection: $season) {
                Text("Select…").tag(Int?.none)
                ForEach(seasons.keys.sorted(), id: \.self) { n in
                    Text(n == 0 ? "Specials" : "Season \(n)").tag(Int?.some(n))
                }
            }
        } else {
            LabeledContent("Season") {
                TextField("Select…", value: $season, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var episodeField: some View {
        if let seasons, let n = season, let count = seasons[n], count > 0 {
            Picker("Episode", selection: $episode) {
                Text("Select…").tag(Int?.none)
                ForEach(1...count, id: \.self) { e in Text("Episode \(e)").tag(Int?.some(e)) }
            }
        } else {
            LabeledContent("Episode") {
                TextField("Select…", value: $episode, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing)
            }
        }
    }

    private func submit() async {
        sending = true
        defer { sending = false }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let scope = isSeries ? self.scope : "item"
        do {
            try await model.client?.reportIssue(IssueCreateBody(
                mediaItemId: mediaItemId, issueType: type, scope: scope,
                season: scope == "item" ? nil : season.map { max(0, $0) },
                episode: scope == "episode" ? episode.map { max(1, $0) } : nil,
                description: trimmed.isEmpty ? nil : trimmed))
            if let onResult { onResult("Issue reported on \(title)", false) } else {
                DiscoverToasts.shared.show(.success, "Issue reported on \(title)")
            }
            dismiss()
        } catch {
            if let onResult { onResult("Could not report issue", true) } else {
                DiscoverToasts.shared.error("Could not report issue", error)
            }
        }
    }
}
