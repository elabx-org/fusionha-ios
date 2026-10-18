import SwiftUI
import FusionhaKit

/// The decision card (web `DecisionCard`), shown in the details sheet: the
/// header (poster, "Pending · 12 m ago", title, kind · source, who asked with
/// their track record, the note), the held guard, the six facts, the usual
/// setup with Adjust, the scope line, then Decline · Skip · Approve.
struct DecisionCardView: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let own: Bool
    let armed: Bool
    let onApprove: () -> Void
    let onDecline: () -> Void
    let onSkip: () -> Void
    let onAdjust: () -> Void
    let onDeclineWithNote: () -> Void
    let onMessage: () -> Void
    let onOpenTitle: () -> Void

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let held = request.held { RequestHeldNote(held: held) }
            DecisionTiles(request: request, triage: triage)
            ApproveSetupRow(triage: triage, own: own, onAdjust: onAdjust)
            RequestScopeLine(request: request, triage: triage)
            actions
        }
    }

    // MARK: Header

    private var header: some View {
        let name = TriageFacts.requesterName(request)
        let age = TriageFacts.compactAge(request.requestedAt)
        return HStack(alignment: .top, spacing: 12) {
            ActPoster(url: request.poster, title: title, size: .md)
            VStack(alignment: .leading, spacing: 6) {
                Text("Pending" + (age.isEmpty ? "" : " · \(age) ago"))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.panel2, in: Capsule())
                (Text(title).fontWeight(.bold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.txt)
                Text("\(TriageFacts.kindText(request, isAnime: triage?.isAnime)) · \(RequestLifecycle.sourceText(request.source))")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                HStack(spacing: 6) {
                    RequestPersonChip(name: name, prefix: "Requested by")
                    if let badge = TriageFacts.trackBadge(triage, role: request.requester?.role) {
                        Text(badge.label)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(badge.trusted ? Theme.done : Theme.mut)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background((badge.trusted ? Theme.done : Theme.mut).opacity(0.14), in: Capsule())
                    }
                }
                if let line = TriageFacts.trackLine(triage) {
                    Text(line + " · last 30 days").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
                if let note = request.note, !note.isEmpty {
                    Text("“\(note)”").font(.system(size: 13).italic()).foregroundStyle(Theme.txt)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button(action: onOpenTitle) { Label("Open title", systemImage: "arrow.up.right.square") }
                Button(action: onMessage) { Label("Message \(TriageFacts.firstName(name))", systemImage: "bubble.left.and.bubble.right") }
                Divider()
                Button(action: onAdjust) { Label("Approve with options…", systemImage: "checkmark") }.disabled(own)
                Button(role: .destructive, action: onDeclineWithNote) { Label("Decline with a note…", systemImage: "xmark") }.disabled(own)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.mut)
                    .frame(width: 40, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("More actions")
        }
    }

    // MARK: Actions

    private var actions: some View {
        let loaded = TriageFacts.loaded(triage)
        let missing = TriageFacts.setupMissing(triage)
        let lowSpace = TriageFacts.lowSpaceMessage(triage)
        let warn = armed && lowSpace != nil
        let scope = RequestScope.head(request, fromEpisode: false)
        let label = warn ? "Approve anyway" : (!loaded ? "Checking space…" : (scope.map { "Approve \($0)" } ?? TriageFacts.approveLabel(request.tiers)))
        let note = own ? TriageFacts.ownRequestNote : (missing ? TriageFacts.setupMissingNote : nil)
        return VStack(alignment: .leading, spacing: 10) {
            if warn, let lowSpace {
                Text("\(lowSpace) Approve again to go ahead anyway.")
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .actWash(Theme.miss, radius: 10, base: Theme.panel2)
            }
            if let note { Text(note).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            HStack(spacing: 8) {
                Button(action: onDecline) { Label("Decline", systemImage: "xmark") }
                    .buttonStyle(.discover(.subtle))
                    .disabled(own)
                Button("Skip", action: onSkip).buttonStyle(.discover(.subtle))
                Spacer(minLength: 0)
                Button(action: onApprove) { Label(label, systemImage: "checkmark").lineLimit(1) }
                    .buttonStyle(.discover(.primary))
                    .disabled(own || missing || !loaded)
            }
        }
    }
}

/// The six facts (web `DecisionTiles`): versions asked, estimated size, free
/// after with the disk bar, 4K release, demand, release.
struct DecisionTiles: View {
    let request: MediaRequest
    let triage: RequestTriage?

    var body: some View {
        let size = TriageFacts.size(triage)
        let free = TriageFacts.freeAfter(triage)
        let release = TriageFacts.release(triage)
        let people = TriageFacts.people(request)
        let demandSub: String? = people.count > 1 ? demandNames(people) : nil
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            TriageTileView(label: "Versions asked", value: Text(request.tiers.map(\.chipLabel).joined(separator: " + ")),
                           sub: request.tiers.count > 1 ? "Tracked as two separate versions" : nil)
            TriageTileView(label: "Estimated size", value: Text(size.value), sub: size.sub)
            TriageTileView(label: "Free after",
                           value: Text(free.value) + Text(free.of.map { " \($0)" } ?? "").font(.system(size: 11)).foregroundColor(Theme.mut),
                           sub: free.sub, tone: free.tone) {
                DiskBar(usedPct: free.usedPct, addPct: free.addPct)
            }
            FourKTile(request: request, triage: triage)
            TriageTileView(label: "Demand", value: Text(TriageFacts.demandText(triage, ownerName: TriageFacts.requesterName(request))),
                           sub: demandSub)
            TriageTileView(label: "Release", value: Text(release.value), sub: release.sub, tone: release.tone)
        }
    }

    /// Owner first, then each joiner, capped at five with "+N more".
    private func demandNames(_ people: [RequestPerson]) -> String {
        var lines: [String] = []
        for (i, p) in people.prefix(5).enumerated() {
            lines.append("\(p.displayName) · \(i == 0 ? "owner" : "joined")")
        }
        if people.count > 5 { lines.append("+\(people.count - 5) more") }
        return lines.joined(separator: "\n")
    }
}

private struct DiskBar: View {
    let usedPct: Double
    let addPct: Double

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Theme.mut.opacity(0.6)).frame(width: geo.size.width * usedPct / 100)
                Rectangle().fill(Theme.grab).frame(width: geo.size.width * addPct / 100)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 4)
        .background(Theme.line, in: Capsule())
        .clipShape(Capsule())
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}

/// 4K RELEASE, with "Check now" for a title not in the library (one live
/// probe through the Discover pre-add check; nothing is stored or grabbed).
private struct FourKTile: View {
    let request: MediaRequest
    let triage: RequestTriage?
    @Environment(AppModel.self) private var model
    @State private var result: FourKCheckResult?
    @State private var checking = false
    @State private var failed = false

    var body: some View {
        let view = TriageFacts.fourK(triage)
        let found = result?.foundUhd
        let value = found == true ? "Available" : (result != nil ? "Not yet" : view.tile.value)
        let sub = subLine(view.tile.sub)
        TriageTileView(label: "4K release", value: Text(value), sub: sub,
                       tone: found == true ? .ok : (result != nil ? nil : view.tile.tone)) {
            if view.checkable && result == nil && (model.me?.hasCapability("search") ?? true) {
                Button(checking ? "Checking…" : "Check now") { Task { await check() } }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(checking)
            }
        }
    }

    private func subLine(_ fallback: String?) -> String? {
        if let result {
            if result.foundUhd { return result.bestReleaseName ?? "Found on \(result.queriedIndexers ?? 0) indexers" }
            return result.dispatched == true ? "No 2160p on \(result.queriedIndexers ?? 0) indexers" : (result.message ?? "Couldn’t check right now")
        }
        return failed ? "Couldn’t check right now" : fallback
    }

    private func check() async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do {
            result = try await client.discoverCheckFourK(DiscoverCheckFourKBody(
                tmdbId: request.tmdbId, title: request.title ?? "", kind: request.kind, year: request.year,
                isAnime: triage?.isAnime ?? false))
        } catch {
            failed = true
        }
    }
}
