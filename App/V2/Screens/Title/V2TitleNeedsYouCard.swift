import SwiftUI
import FusionhaKit

/// What on this title needs the owner (mock kit `needs`): the problem, what
/// Fusionha does meanwhile, and Review. Shown only while a download is held
/// or a version's files need attention. Orange is the one warning hue.
struct V2TitleNeedsYouCard: View {
    let item: V2TitleNeed
    let review: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.stuck, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Text(item.line)
                    .font(.system(size: 12.5))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Review", action: review)
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.glassProminent)
                .tint(Theme.stuck)
                .v2ClearsColumn()
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .background {
            ZStack {
                ModuleSurface(radius: 20)
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.stuck.opacity(0.13))
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stuck.opacity(0.4), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One thing that needs the owner: a held download (Review opens it in the
/// Queue) or a version whose files need attention (Review opens Files).
struct V2TitleNeed: Identifiable {
    enum Target { case queue(downloadId: Int), files(DetailEdition) }
    let id: String
    let title: String
    let line: String
    let target: Target

    /// Held downloads first, then versions with attention, at most `limit`.
    @MainActor
    static func all(store: DetailStore, detail: ItemDetail, limit: Int = 2) -> [V2TitleNeed] {
        var out: [V2TitleNeed] = []
        for row in store.queue where QueueProgress(row).held {
            let what = [row.episodeLabel, row.tier.badgeLetters].compactMap { $0 }.joined(separator: " in ")
            out.append(V2TitleNeed(id: "q\(row.id)", title: "\(what) is held",
                                   line: row.heldReason ?? row.warning ?? "Fusionha is waiting for you to decide",
                                   target: .queue(downloadId: row.id)))
        }
        for edition in detail.orderedEditions where edition.attentionKind != nil || edition.unresolvedCount > 0 {
            let line = edition.attentionMessage
                ?? "\(edition.unresolvedCount) file\(edition.unresolvedCount == 1 ? "" : "s") not found on the last scan"
            out.append(V2TitleNeed(id: "e\(edition.id)", title: "\(edition.tier.badgeLetters) needs you", line: line,
                                   target: .files(edition)))
        }
        return Array(out.prefix(limit))
    }
}
