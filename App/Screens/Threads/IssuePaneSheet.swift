import SwiftUI
import FusionhaKit

/// A manager's issue thread (web A7 `IssuePane`): where it stands, the linked
/// pending request, each report with its evidence and any set-aside copy,
/// the History strip of fix grabs, the action chips, the conversation and a
/// reply aimed at one reporter or everyone here.
struct IssuePaneSheet: View {
    let seed: MediaIssue
    let linkedRequestId: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var issue: MediaIssue?
    @State private var linked: MediaRequest?
    @State private var grabs: IssueFixGrabs?
    @State private var events: [RequestThreadEvent] = []
    @State private var marked = 0
    @State private var tick = 0
    @State private var audience: IssueAudience = .default_
    @State private var dialog: StagedDialogRoute?

    private var current: MediaIssue { issue ?? seed }
    private var manager: Bool { model.me?.hasPermission("issues.manage") ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    IssueThreadBannerView(banner: ThreadBanner.banner(current, reopenedBy: reopenedBy))
                    if let linked { linkedHint(linked) }
                    section("Reports") {
                        IssueManagerReportCards(reports: current.reports ?? [], manager: manager) { kind, report in
                            dialog = StagedDialogRoute(kind: kind, report: report)
                        }
                    }
                    if manager, let grabs, !grabs.groups.isEmpty { IssueHistoryStrips(grabs: grabs, fallbackTitle: current.mediaTitle ?? "This title") }
                    IssueActionChips(issue: current, linked: linked?.status == "pending" ? linked : nil,
                                     manager: manager, onDialog: { dialog = $0 }) { tick += 1 }
                    section("Thread") {
                        RequestConversation(events: events.filter { !IssueFormat.isMarkerLine($0) }, loaded: true, joinedView: false)
                    }
                    Color.clear.frame(height: 1)
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) { composer }
            .background(Theme.bg)
            .navigationTitle(current.mediaTitle ?? "Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss(); model.open(current.mediaItemId) } label: { Image(systemName: "arrow.up.right.square") }
                        .accessibilityLabel("Open in library")
                }
            }
            .sheet(item: $dialog) { route in
                StagedDialogSheet(issueId: current.id, route: route, onSwitch: { dialog = $0 }) { tick += 1 }
            }
        }
        .presentationDetents([.large])
        .task(id: tick) { await pollIssue() }
        .task { await pollLines() }
    }

    // MARK: Header and parts

    private var header: some View {
        let reports = current.reports ?? []
        var tiers: [QualityTier] = []
        for t in reports.compactMap(\.version.tier) where !tiers.contains(t) { tiers.append(t) }
        let people = current.participantsCount ?? 0
        return HStack(spacing: 12) {
            ActPoster(url: current.poster, title: current.mediaTitle ?? "Issue", size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                (Text(current.mediaTitle ?? "Issue").fontWeight(.bold) + Text(verbatim: current.mediaYear.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 17)).foregroundStyle(Theme.txt)
                HStack(spacing: 6) {
                    IssueStateChip(state: current.state ?? "OPEN", reopenCount: current.reopenCount ?? 0)
                    ForEach(tiers, id: \.self) { ActTierChip(tier: $0) }
                    Text("\(reports.count == 1 ? "1 report" : "\(reports.count) reports") · \(people) \(people == 1 ? "person" : "people")")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    /// "Linked request #1234 · HD · asked by Sam · Pending" (web `LinkedRequestHint`).
    private func linkedHint(_ r: MediaRequest) -> some View {
        let wash = RequestLifecycle.wash(status: r.status, lifecycle: r.lifecycle ?? [])
        let tint = wash == .none ? Theme.dim : wash.color
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tray").foregroundStyle(Theme.mut)
            ActFlow(spacing: 6, lineSpacing: 4) {
                Text("Linked request ").font(.system(size: 12.5)) + Text(verbatim: "#\(r.id)").bold().font(.system(size: 12.5))
                ForEach(r.tiers, id: \.self) { ActTierChip(tier: $0) }
                if let who = r.requester?.displayName {
                    (Text("· asked by ").foregroundColor(Theme.mut) + Text(who).bold()).font(.system(size: 12.5)).lineLimit(1)
                }
                Text(RequestBoard.statusLabel(r.status))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(tint.opacity(0.14), in: Capsule())
            }
        }
        .foregroundStyle(Theme.txt)
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func section<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            content()
        }
    }

    private var reopenedBy: (name: String?, admin: Bool)? {
        events.last { $0.eventType == "reopened" }.map { ($0.actor?.displayName, $0.actorKind == "ADMIN") }
    }

    @ViewBuilder
    private var composer: some View {
        let people = IssueChipRules.reporters(current.reports ?? [])
        VStack(spacing: 6) {
            IssueAudiencePicker(people: people, picked: $audience,
                                defaultId: IssueChipRules.defaultAudience(current.reports ?? [], openerId: current.reporterUserId, authorId: model.me?.id))
            RequestThreadComposer(placeholder: "Write a reply…", post: { [id = current.id, audience] client, body in
                switch audience {
                case .everyone: return try await client.postIssueMessage(id: id, body: body, audienceUserId: nil, everyone: true)
                case .person(let uid): return try await client.postIssueMessage(id: id, body: body, audienceUserId: uid, everyone: false)
                case .default_: return try await client.postIssueMessage(id: id, body: body)
                }
            }) { line in append([line]) }
            Text("Only the people you pick see this. Reporters never see each other.")
                .font(.system(size: 12)).foregroundStyle(Theme.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
    }

    // MARK: Polling

    private func pollIssue() async {
        guard let client = model.client else { return }
        if let id = linkedRequestId, model.me?.hasPermission("requests.approve") == true {
            linked = try? await client.requestDetail(id: id)
        }
        while !Task.isCancelled {
            if let fresh = try? await client.issue(id: seed.id) { issue = fresh }
            if manager { grabs = (try? await client.issueFixGrabs(id: seed.id)) ?? grabs }
            try? await Task.sleep(for: .seconds(15))
        }
    }

    private func pollLines() async {
        while !Task.isCancelled {
            if let client = model.client, let fresh = try? await client.issueEvents(id: seed.id, afterId: events.last?.id ?? 0) {
                append(fresh)
                if let last = events.last?.id, last > marked {
                    marked = last
                    try? await client.markIssueRead(id: seed.id, lastEventId: last)
                }
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func append(_ lines: [RequestThreadEvent]) {
        let known = Set(events.map(\.id))
        let fresh = lines.filter { !known.contains($0.id) }
        if !fresh.isEmpty { events = (events + fresh).sorted { $0.id < $1.id } }
    }
}

/// Who a manager's reply goes to.
enum IssueAudience: Hashable {
    case default_, everyone, person(Int)
}

/// "Reply to": one reporter, or everyone here (with two or more); with nobody
/// picked the server chooses, shown as a hint (web `AudiencePicker`).
struct IssueAudiencePicker: View {
    let people: [RequestPerson]
    @Binding var picked: IssueAudience
    let defaultId: Int?

    var body: some View {
        if !people.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Reply to").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    ForEach(people, id: \.id) { p in
                        if let id = p.id { chip(p.displayName, on: picked == .person(id), isDefault: picked == .default_ && id == defaultId) {
                            picked = picked == .person(id) ? .default_ : .person(id)
                        } }
                    }
                    if people.count > 1 {
                        chip("Everyone here", on: picked == .everyone, isDefault: picked == .default_ && defaultId == nil) {
                            picked = picked == .everyone ? .default_ : .everyone
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: people.compactMap(\.id)) {
                if case .person(let id) = picked, !people.contains(where: { $0.id == id }) { picked = .default_ }
                if picked == .everyone && people.count < 2 { picked = .default_ }
            }
        }
    }

    private func chip(_ text: String, on: Bool, isDefault: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.txt)
                .padding(.horizontal, 10).frame(height: 28)
                .background(on ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.panel2), in: Capsule())
                .overlay(Capsule().strokeBorder(isDefault ? Theme.mut : .clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityHint(isDefault ? "Default" : "")
    }
}
