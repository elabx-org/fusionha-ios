import SwiftUI
import FusionhaKit

// The Request sheet's options in v2 (look pass family 5, mock look-b.js
// `request`): every v1 field and line, as sentence-case sections of solid
// inset-grouped rows on the glass sheet. Versions are check rows with their
// media badge and per-row tag; the hint lines stay under their cards.
extension RequestModal {
    var optionsPaneV2: some View {
        VStack(alignment: .leading, spacing: 8) {
            if demand?.state == "me_too", let asked = demand?.asked {
                RequestDemandBanner(asked: asked).padding(.bottom, 12)
            }
            RequestGroupLabel(text: "Versions")
            editionsV2
            if isSeries && !nothingOfferable {
                RequestGroupLabel(text: "Seasons & episodes").padding(.top, 14)
                RequestSeasonPicker(pick: pick, preview: preview, loaded: previewLoaded,
                                    selSeasons: $selSeasons, selEpisodes: $selEpisodes)
            }
            if picks.isEmpty || !picks.allSatisfy({ $0.act == .watch }) {
                RequestGroupLabel(text: "Note for the approver", trailing: "optional").padding(.top, 14)
                RequestGroupCard {
                    TextField("", text: $note, prompt: Text("Anything the approver should know…").foregroundStyle(Theme.dim),
                              axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.txt)
                        .padding(14)
                        .frame(minHeight: 76, alignment: .topLeading)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
    }

    @ViewBuilder
    private var editionsV2: some View {
        if offerFailed {
            hintCard("Could not load your access — try again.")
        } else if let offer {
            if nothingOfferable {
                hintCard("Nothing to request — you already have every version you can access.")
            } else if offer.isAuto {
                autoCardV2
            } else {
                RequestGroupCard {
                    ForEach(Array(offerTiers.enumerated()), id: \.element) { index, tier in
                        if index > 0 { RequestRowDivider() }
                        RequestVersionRow(tier: tier, selected: selectedTiers.contains(tier),
                                          act: RequestOffer.tagged(demand) ? RequestOffer.act(demand, tier: tier) : nil,
                                          asked: demand?.asked ?? 0) {
                            if selectedTiers.contains(tier) { selectedTiers.remove(tier) } else { selectedTiers.insert(tier) }
                        }
                    }
                }
                hint(offerTiers.allSatisfy { RequestOffer.act(demand, tier: $0) == .watch }
                     ? "No approval and no quota. You're told when it lands."
                     : "Pick one or both — HD and 4K are separate libraries, each grabbed & tracked on its own.")
            }
        } else {
            hintCard("Checking what you can request…")
        }
    }

    /// The admin set the quality: the lock line and the versions it goes to.
    private var autoCardV2: some View {
        RequestGroupCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock").font(.system(size: 15)).foregroundStyle(Theme.mut)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    (Text("Quality is set by the admin. This request goes to your ")
                     + Text(offerTiers.map(\.chipLabel).joined(separator: " + ")).foregroundColor(Theme.txt).fontWeight(.semibold)
                     + Text(" library — you don't choose per-request."))
                        .font(.system(size: 14)).foregroundStyle(Theme.mut)
                    HStack(spacing: 6) {
                        ForEach(offerTiers, id: \.self) { tier in
                            EditionBadge(tier: tier, state: .missing, showsCount: false)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func hintCard(_ text: String) -> some View {
        RequestGroupCard {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .padding(14)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 12)
            .padding(.top, 2)
    }
}
