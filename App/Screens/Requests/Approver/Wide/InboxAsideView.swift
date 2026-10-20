import SwiftUI
import FusionhaKit

/// The wide Inbox's right pane (web `InboxAside`, 0.4.217, Final mock
/// `.fin-dcard`): the poster, title, "Requested by … · age", the tier chips
/// and the source in words, the one setup line, then Approve, Decline,
/// Adjust and Details. The facts, track record, Message and Skip live in
/// Details (the full `DecisionCardView`, as a sheet).
struct InboxAsideView: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let own: Bool
    let armed: Bool
    let onApprove: () -> Void
    let onDecline: () -> Void
    let onAdjust: () -> Void
    let onDetails: () -> Void

    private var title: String { request.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let held = request.held { RequestHeldNote(held: held) }
            if let lines = InboxAsideFacts.setupLines(triage), !lines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(lines, id: \.self) { Text($0).lineLimit(1).truncationMode(.middle) }
                }
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                .padding(.horizontal, 11).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            RequestScopeLine(request: request, triage: triage)
            notes
            actions
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Decide: \(title)")
    }

    private var header: some View {
        let age = TriageFacts.compactAge(request.requestedAt)
        return HStack(alignment: .top, spacing: 14) {
            PosterImage(url: TMDBImage.resized(request.poster, to: "w342"))
                .overlay {
                    if request.poster == nil {
                        Text(String(title.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.mut)
                    }
                }
                .frame(width: 96, height: 144)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                (Text(title).fontWeight(.bold) + Text(verbatim: request.year.map { " (\($0))" } ?? "").fontWeight(.medium).foregroundColor(Theme.mut))
                    .font(.system(size: 17)).foregroundStyle(Theme.txt)
                (Text("Requested by ") + Text(TriageFacts.requesterName(request)).fontWeight(.semibold).foregroundColor(Theme.txt)
                 + Text(age.isEmpty ? "" : " · \(age) ago"))
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                ActFlow(spacing: 8, lineSpacing: 6) {
                    ForEach(request.tiers, id: \.self) { ActTierChip(tier: $0) }
                    Text(RequestSourceWords.phrase(request.source, mine: false))
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var notes: some View {
        let lowSpace = TriageFacts.lowSpaceMessage(triage)
        if armed, let lowSpace {
            Text("\(lowSpace) Approve again to go ahead anyway.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.txt)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .actWash(Theme.miss, radius: 11, base: Theme.card)
        }
        if let note = own ? TriageFacts.ownRequestNote : (TriageFacts.setupMissing(triage) ? TriageFacts.setupMissingNote : nil) {
            Text(note).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
        }
    }

    private var actions: some View {
        let checking = !TriageFacts.loaded(triage)
        let warn = armed && TriageFacts.lowSpaceMessage(triage) != nil
        let scope = RequestScope.head(request, fromEpisode: false)
        let label = warn ? "Approve anyway" : (checking ? "Checking space…" : (scope.map { "Approve \($0)" } ?? "Approve"))
        return ActFlow(spacing: 8, lineSpacing: 8) {
            Button(action: onApprove) { Label(label, systemImage: "checkmark") }
                .buttonStyle(.discover(.primary))
                .disabled(own || TriageFacts.setupMissing(triage) || checking)
            Button(action: onDecline) { Label("Decline", systemImage: "xmark") }
                .buttonStyle(.discover(.danger))
                .overlay(Capsule().strokeBorder(Theme.danger.opacity(0.55)))
                .disabled(own)
            Button("Adjust", action: onAdjust).buttonStyle(.discover(.ghost)).disabled(own)
            Button("Details", action: onDetails).buttonStyle(.discover(.ghost))
        }
    }
}

/// The aside's one setup line per requested version (web `inbox-aside-facts`):
/// "Root /movies · 41 GB free · profile HD-1080p"; nil while triage loads.
enum InboxAsideFacts {
    static func setupLines(_ triage: RequestTriage?) -> [String]? {
        guard let triage else { return nil }
        let disk = TriageFacts.tightestDisk(triage.disks)
        let free = disk?.freeBytes.map { " · \(DetailText.bytes($0)) free" } ?? ""
        return triage.versions.enumerated().map { i, v in
            v.configured
                ? "Root \(v.rootPath ?? "")\(i == 0 ? free : "") · profile \(v.profileName ?? "")"
                : "No Add default for this version yet"
        }
    }
}
