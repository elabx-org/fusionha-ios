import SwiftUI
import FusionhaKit

/// One request as a live card (web R1 `RequestCard`): poster, title and
/// year, the requested versions · kind · when, who approved it and where it
/// came from (or "Joined · N asked", or that an admin is already searching),
/// any other version's own state, "Also requested by N others", then the
/// lead version's stepper and status line, or the declined / waiting /
/// withdrawn note. Actions: the conversation, Withdraw or Leave, Open in
/// Plex and Report an issue. Status is the card's wash.
struct RequestCardView: View {
    let request: MediaRequest
    let plexURL: String?
    let onOpenThread: () -> Void
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var reporting = false
    @State private var working = false

    private var lifecycle: [RequestLifecycleEntry] { request.lifecycle ?? [] }
    private var title: String {
        request.title ?? PreviewCache.shared.get(request.previewKind, request.tmdbId)?.title ?? "TMDB #\(request.tmdbId)"
    }

    var body: some View {
        let lead = RequestLifecycle.lead(lifecycle)
        let lagging = RequestLifecycle.lagging(lifecycle, lead: lead)
        let joined = RequestLifecycle.isJoinedView(request, viewerId: model.me?.id)
        let declined = request.status == "rejected" || request.status == "deferred"
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ActPoster(url: request.poster, title: title, size: .md)
                VStack(alignment: .leading, spacing: 5) {
                    (Text(title).fontWeight(.bold) + Text(request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(2)
                    metaLine
                    whoLine(joined: joined)
                    ForEach(Array(lagging.enumerated()), id: \.offset) { _, e in
                        Text("\(e.tier.chipLabel) · \(RequestLifecycle.versionWord(e))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(e.needsManualImport ? Theme.stuck : Theme.mut)
                    }
                    if !joined, let demand = request.demand, demand.count > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundStyle(Theme.mut)
                            (Text("Also requested by \(demand.count - 1) \(demand.count == 2 ? "other" : "others")").fontWeight(.semibold)
                             + Text(" · everyone is notified when it’s available").foregroundColor(Theme.mut))
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.txt)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            timeline(lead: lead, lagging: lagging, declined: declined)
            actions(lead: lead, joined: joined, declined: declined)
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenThread)
        .actWash(RequestLifecycle.wash(status: request.status, lifecycle: lifecycle).color, radius: 16, base: Theme.card)
        .sheet(isPresented: $reporting) {
            if let id = request.mediaItemId {
                IssueModal(mediaItemId: id, title: title, isSeries: request.kind == .series, seasons: nil)
            }
        }
    }

    // MARK: Lines

    private var metaLine: some View {
        HStack(spacing: 6) {
            ForEach(request.tiers ?? [request.tier], id: \.self) { ActTierChip(tier: $0) }
            Text("·").foregroundStyle(Theme.dim)
            Text(RequestLifecycle.kindLabel(request))
            if let at = request.requestedAt.flatMap(ServerTime.parse) {
                Text("·").foregroundStyle(Theme.dim)
                Text(at, style: .relative) + Text(" ago")
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.mut)
        .lineLimit(1)
    }

    @ViewBuilder
    private func whoLine(joined: Bool) -> some View {
        ActFlow(spacing: 8, lineSpacing: 4) {
            if joined {
                RequestPersonChip(name: request.requester?.displayName ?? "Another requester", prefix: nil)
                Label("Joined · \(request.demand?.count ?? 1) asked", systemImage: "checkmark")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.i2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.i2.opacity(0.14), in: Capsule())
            } else if request.watch == true {
                Label("Watching", systemImage: "eye").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.grab)
                Text("Admin is already searching · no approval needed").font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                if let by = request.approvedBy {
                    if by.kind == "auto" {
                        Label(RequestLifecycle.autoText(by), systemImage: "bolt.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.done.opacity(0.14), in: Capsule())
                    } else {
                        RequestPersonChip(name: by.displayName ?? "An admin", prefix: "Approved by")
                    }
                }
                Text(RequestLifecycle.sourceText(request.source)).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
    }

    @ViewBuilder
    private func timeline(lead: RequestLifecycleEntry?, lagging: [RequestLifecycleEntry], declined: Bool) -> some View {
        if request.status == "waiting" {
            HStack(spacing: 10) {
                Image(systemName: "clock").foregroundStyle(Theme.miss)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Waiting for quota").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("Requests when your quota resets").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
        } else if declined {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let by = request.declinedBy {
                        RequestPersonChip(name: by.displayName, prefix: request.status == "deferred" ? "Deferred by" : "Declined by")
                    }
                    if let reason = RequestLifecycle.reasonLabel(request.reason) {
                        Text(reason).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.danger)
                    }
                }
                if let note = request.decisionNote {
                    Text("“\(note)”").font(.system(size: 13).italic()).foregroundStyle(Theme.mut)
                }
            }
        } else if request.status == "withdrawn" {
            Text("Withdrawn").font(.system(size: 13)).foregroundStyle(Theme.mut)
        } else if let lead {
            VStack(alignment: .leading, spacing: 10) {
                RequestStepperView(entry: lead, auto: request.approvedBy?.kind == "auto")
                if let line = RequestLifecycle.statusLine(request, lead: lead, lagging: lagging) {
                    RequestStatusLineView(line: line)
                }
            }
        }
    }

    private func actions(lead: RequestLifecycleEntry?, joined: Bool, declined: Bool) -> some View {
        let unread = request.thread?.unread ?? 0
        return HStack(spacing: 6) {
            Button(action: onOpenThread) {
                Image(systemName: declined ? "arrowshape.turn.up.left" : "bubble.left.and.bubble.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(declined ? Theme.i2 : Theme.mut)
                    .frame(width: 40, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if unread > 0 { Circle().fill(Theme.i2).frame(width: 8, height: 8).offset(x: -6, y: 8) }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(declined ? "Reply" : "Open conversation") · \(title)\(unread > 0 ? " · \(unread) unread" : "")")
            if RequestLifecycle.canWithdraw(request, lead: lead, viewerId: model.me?.id) {
                QueueIconSlot(icon: "trash", label: request.watch == true ? "Stop watching" : "Withdraw request", tint: Theme.danger) {
                    Task { await run { try await $0.withdrawRequest(id: request.id) } }
                }
                .disabled(working)
            }
            if joined {
                QueueIconSlot(icon: "xmark", label: "Leave request") {
                    Task { await run { try await $0.leaveRequest(id: request.id) } }
                }
                .disabled(working)
            }
            Spacer(minLength: 0)
            if request.status == "fulfilled", let plexURL, let url = URL(string: plexURL) {
                Button { openURL(url) } label: {
                    Label("Open in Plex", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color(hex: 0xE5A00D), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(title) in Plex")
            }
            if request.status == "fulfilled", request.mediaItemId != nil {
                Button("Report an issue") { reporting = true }
                    .buttonStyle(ActButtonStyle(kind: .subtle))
            }
        }
    }

    private func run(_ call: @escaping (APIClient) async throws -> Void) async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            try await call(client)
            onChanged()
        } catch {
            model.toast(ErrorCopy.message(for: error), variant: .error)
        }
    }
}

/// A person: initials avatar, an optional prefix, the name.
struct RequestPersonChip: View {
    let name: String
    let prefix: String?

    var body: some View {
        HStack(spacing: 5) {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 18, height: 18)
                .background(Theme.fusion, in: Circle())
            if let prefix { Text(prefix).foregroundStyle(Theme.mut) }
            Text(name).fontWeight(.semibold).foregroundStyle(Theme.txt)
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }
}
