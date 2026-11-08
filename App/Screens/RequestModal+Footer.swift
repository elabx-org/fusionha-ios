import SwiftUI
import FusionhaKit

// The Request sheet's footer: the summary line, quota pips and Request (or
// the quota prompt after a 409), and the submit path. v2's bar is
// `footerBarV2` (look pass family 5).
extension RequestModal {
    /// The footer line; a tagged ask bolds its act words (web `ActSummary`).
    var summary: Text {
        if picks.contains(where: { $0.act != .new }), offer != nil, !nothingOfferable {
            var line = Text(verbatim: "")
            for (index, part) in RequestOffer.summaryParts(picks, limited: quota?.limit != nil).enumerated() {
                let lead: Text = Text(verbatim: part.lead).fontWeight(.bold).foregroundColor(Theme.txt)
                let gap: Text = Text(verbatim: index > 0 ? " · " : "")
                line = line + gap + lead + Text(verbatim: part.rest)
            }
            return line
        }
        return Text(verbatim: summaryLine)
    }

    var summaryLine: String {
        if offer == nil && !offerFailed { return "Checking what you can request…" }
        if offerFailed { return "Could not check available versions." }
        if nothingOfferable { return "Nothing to request — you already have every version you can access." }
        if editionsToSend.isEmpty { return "Select a version" }
        let tiers = editionsToSend.map(\.chipLabel).joined(separator: " + ")
        let title = preview?.title ?? pick.title
        guard isSeries else { return "Requesting \(title) · \(tiers)" }
        var parts: [String] = []
        if !selSeasons.isEmpty { parts.append("\(selSeasons.count) season\(selSeasons.count > 1 ? "s" : "")") }
        if !selEpisodes.isEmpty { parts.append("\(selEpisodes.count) episode\(selEpisodes.count > 1 ? "s" : "")") }
        return "Requesting \(title) · \(tiers) · \(parts.isEmpty ? "Whole series" : parts.joined(separator: " + "))"
    }

    @ViewBuilder
    var footer: some View {
        if blocked != nil {
            RequestQuotaPrompt(quota: quota, pending: sending, wishlistDisabled: editionsToSend.isEmpty, joinTiers: joinTiers,
                               onWishlist: { send(currentBody(wishlist: true)) },
                               onJoinOnly: { send(currentBody(tiers: joinTiers, join: true)) },
                               onCancel: { blocked = nil })
                .background(ProductLook.isV2 ? Color.clear : Theme.panel)
                .overlay(alignment: .top) {
                    if !ProductLook.isV2 { Rectangle().fill(Theme.line).frame(height: 1) }
                }
        } else {
            let label = RequestOffer.submitLabel(picks.map(\.act))
            if ProductLook.isV2 {
                footerBarV2(label: label)
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        summary.font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(3)
                        RequestQuotaMini(quota: quota)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if canSubmit { send(currentBody()) }
                    } label: {
                        Label(sending ? "\(label == "Request" ? "Requesting" : label)…" : label,
                              systemImage: label == "Watch" ? "eye" : (label == "Me too" ? "person.2.fill" : "plus"))
                    }
                    .buttonStyle(.discover(.primary))
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(Theme.panel)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
        }
    }

    /// The ask as the form stands now; the quota prompt's re-sends rebuild it too.
    func currentBody(tiers: [QualityTier]? = nil, join: Bool = false, wishlist: Bool = false) -> RequestCreateBody {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let episodes = selEpisodes.sorted { ($0.season, $0.episode) < ($1.season, $1.episode) }
        return RequestCreateBody(
            tmdbId: pick.tmdbId, kind: pick.kind, editions: tiers ?? editionsToSend,
            seasons: isSeries ? selSeasons.sorted() : [], episodes: isSeries ? episodes : [],
            note: trimmed.isEmpty ? nil : trimmed, join: join, wishlist: wishlist)
    }

    func send(_ body: RequestCreateBody) {
        Task { await submit(body) }
    }

    /// A 409 `quota` swaps the footer for the wishlist prompt instead of a toast.
    func submit(_ body: RequestCreateBody) async {
        guard !sending, let client = model.client else { return }
        sending = true
        defer { sending = false }
        do {
            let result = try await client.submitRequest(body)
            blocked = nil
            DiscoverToasts.shared.show(.success, RequestOffer.successCopy(result, title: preview?.title ?? pick.title))
            onDone()
            dismiss()
        } catch let error as APIError where error.code == "quota" && body.wishlist != true {
            blocked = body
        } catch {
            blocked = nil
            DiscoverToasts.shared.error("Could not submit request", error)
        }
    }

    /// v2: the summary and the accent Request capsule on a glass bar.
    func footerBarV2(label: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                summary.font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(3)
                RequestQuotaMini(quota: quota)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if canSubmit { send(currentBody()) }
            } label: {
                Label(sending ? "\(label == "Request" ? "Requesting" : label)…" : label,
                      systemImage: label == "Watch" ? "eye" : (label == "Me too" ? "person.2.fill" : "plus"))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Theme.primary)
            .disabled(!canSubmit)
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
}
