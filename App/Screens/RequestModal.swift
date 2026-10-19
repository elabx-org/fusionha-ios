import SwiftUI
import FusionhaKit

// MARK: - RequestModal

struct RequestModal: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let pick: MediaSearchResult
    let onDone: () -> Void

    @State private var offer: OfferableEditions?
    @State private var offerFailed = false
    @State private var preview: MediaPreviewDetail?
    @State private var selectedTiers: Set<QualityTier> = []
    @State private var selSeasons: Set<Int> = []
    @State private var selEpisodes: Set<EpisodeRef> = []
    @State private var note = ""
    @State private var sending = false
    @State private var previewLoaded = false
    @State private var demand: RequestTitleDemand?
    @State private var quota: RequestQuota?
    /// The ask the server refused for quota; non-nil shows the wishlist prompt.
    @State private var blocked: RequestCreateBody?

    private var isSeries: Bool { pick.kind == .series }
    /// The versions on offer: the server's per-viewer demand list (join, Watch
    /// or a new ask) when it answered, else the offerable set.
    private var offerTiers: [QualityTier] {
        guard let offer else { return [] }
        return RequestOffer.tiers(demand: demand, fallback: offer.isAuto ? offer.autoEditions : offer.editions)
    }
    private var editionsToSend: [QualityTier] {
        guard let offer else { return [] }
        return offer.isAuto ? offerTiers : offerTiers.filter { selectedTiers.contains($0) }
    }
    private var picks: [(tier: QualityTier, act: RequestOffer.Act)] {
        editionsToSend.map { ($0, RequestOffer.act(demand, tier: $0)) }
    }
    private var joinTiers: [QualityTier] { picks.filter { $0.act == .join }.map(\.tier) }
    private var nothingOfferable: Bool { offer != nil && offerTiers.isEmpty }
    private var canSubmit: Bool { offer != nil && !nothingOfferable && !editionsToSend.isEmpty && !sending }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    RequestModalArt(pick: pick, preview: preview)
                    optionsPane
                }
            }
            // The art runs under the clear bar, as before the system Close.
            .ignoresSafeArea(.container, edges: .top)
            footer
        }
        .background(Theme.panel)
        // Close is a system toolbar item (DC10); presenters give the modal a
        // stack (`NavigationStack { RequestModal(…) }`), the Add sheet its own.
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                SheetCancelButton(title: "Close") { dismiss() }
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .closeOnlyBars()
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .presentationCornerRadius(14)
        .task { await load() }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let offerCall = client.offerableEditions(kind: pick.kind, tmdbId: pick.tmdbId)
        async let previewCall = client.previewDetail(kind: pick.previewKind, tmdbId: pick.tmdbId)
        async let demandCall = try? client.requestDemand(kind: pick.kind, tmdbIds: [pick.tmdbId])
        async let quotaCall = try? client.requestQuota()
        do {
            let loaded = try await offerCall
            demand = await demandCall?.first { $0.tmdbId == pick.tmdbId }
            quota = await quotaCall
            offer = loaded
            selectedTiers = Set(offerTiers)
        } catch {
            offerFailed = true
        }
        preview = try? await previewCall
        previewLoaded = true
    }

    // MARK: Options pane

    private var optionsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            if demand?.state == "me_too", let asked = demand?.asked { RequestDemandBanner(asked: asked) }
            VStack(alignment: .leading, spacing: 10) {
                DialogSectionLabel(text: "Versions")
                editions
            }
            // Nothing on offer: no seasons to scope (web `isSeries && !nothingOfferable`).
            if isSeries && !nothingOfferable {
                VStack(alignment: .leading, spacing: 10) {
                    DialogSectionLabel(text: "Seasons & episodes")
                    RequestSeasonPicker(pick: pick, preview: preview, loaded: previewLoaded,
                                        selSeasons: $selSeasons, selEpisodes: $selEpisodes)
                }
            }
            if picks.isEmpty || !picks.allSatisfy({ $0.act == .watch }) {
                VStack(alignment: .leading, spacing: 10) {
                    DialogSectionLabel(text: "Note for the approver", trailing: "optional")
                    TextField("", text: $note, prompt: Text("Anything the approver should know…").foregroundStyle(Theme.dim),
                              axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.txt)
                        .padding(11)
                        .frame(minHeight: 64, alignment: .topLeading)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 8)
    }

    @ViewBuilder
    private var editions: some View {
        if offerFailed {
            dashed("Could not load your access — try again.")
        } else if let offer {
            if nothingOfferable {
                dashed("Nothing to request — you already have every version you can access.", color: Theme.mut, centred: true)
            } else if offer.isAuto {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock").font(.system(size: 14)).foregroundStyle(Theme.dim)
                        (Text("Quality is set by the admin. This request goes to your ")
                         + Text(offerTiers.map(\.chipLabel).joined(separator: " + ")).foregroundColor(Theme.txt).fontWeight(.semibold)
                         + Text(" library — you don't choose per-request."))
                            .font(.system(size: 13)).foregroundStyle(Theme.mut)
                    }
                    HStack(spacing: 6) {
                        ForEach(offerTiers, id: \.self) { tier in
                            Text(tier.chipLabel).font(.system(size: 11, weight: .bold)).foregroundStyle(tier.color)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(tier.color.opacity(0.15), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(offerTiers, id: \.self) { tier in
                        let selected = selectedTiers.contains(tier)
                        Button {
                            if selected { selectedTiers.remove(tier) } else { selectedTiers.insert(tier) }
                        } label: {
                            HStack(spacing: 13) {
                                WebCheckSquare(checked: selected, color: tier.color, ink: tier.ink)
                                RoundedRectangle(cornerRadius: 3).fill(tier.color).frame(width: 9, height: 9)
                                Text(tier.chipLabel).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                                Spacer(minLength: 0)
                                if RequestOffer.tagged(demand) {
                                    RequestTierTag(act: RequestOffer.act(demand, tier: tier), asked: demand?.asked ?? 0)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 13)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(selected ? tier.color.opacity(0.55) : Theme.line))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(DiscoverPressStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    Text(offerTiers.allSatisfy { RequestOffer.act(demand, tier: $0) == .watch }
                         ? "No approval and no quota. You're told when it lands."
                         : "Pick one or both — HD and 4K are separate libraries, each grabbed & tracked on its own.")
                        .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
            }
        } else {
            dashed("Checking what you can request…")
        }
    }

    private func dashed(_ text: String, color: Color = Theme.dim, centred: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(color)
            .multilineTextAlignment(centred ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    // MARK: Footer

    /// The footer line; a tagged ask bolds its act words (web `ActSummary`).
    private var summary: Text {
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

    private var summaryLine: String {
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
    private var footer: some View {
        if blocked != nil {
            RequestQuotaPrompt(quota: quota, pending: sending, wishlistDisabled: editionsToSend.isEmpty, joinTiers: joinTiers,
                               onWishlist: { send(currentBody(wishlist: true)) },
                               onJoinOnly: { send(currentBody(tiers: joinTiers, join: true)) },
                               onCancel: { blocked = nil })
                .background(Theme.panel)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        } else {
            let label = RequestOffer.submitLabel(picks.map(\.act))
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

    /// The ask as the form stands now; the quota prompt's re-sends rebuild it too.
    private func currentBody(tiers: [QualityTier]? = nil, join: Bool = false, wishlist: Bool = false) -> RequestCreateBody {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let episodes = selEpisodes.sorted { ($0.season, $0.episode) < ($1.season, $1.episode) }
        return RequestCreateBody(
            tmdbId: pick.tmdbId, kind: pick.kind, editions: tiers ?? editionsToSend,
            seasons: isSeries ? selSeasons.sorted() : [], episodes: isSeries ? episodes : [],
            note: trimmed.isEmpty ? nil : trimmed, join: join, wishlist: wishlist)
    }

    private func send(_ body: RequestCreateBody) {
        Task { await submit(body) }
    }

    /// A 409 `quota` swaps the footer for the wishlist prompt instead of a toast.
    private func submit(_ body: RequestCreateBody) async {
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
}
