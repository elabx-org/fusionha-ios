import SwiftUI
import FusionhaKit

// The Request sheet's options: the demand banner, Versions, Seasons &
// episodes and the note. v1 as it was; v2 (look pass family 5) on solid
// inset-grouped cards (`RequestSheetV2Parts`).
extension RequestModal {
    @ViewBuilder
    var optionsPane: some View {
        if ProductLook.isV2 { optionsPaneV2 } else { optionsPaneV1 }
    }

    /// v1's options pane (v2 draws `optionsPaneV2`).
    var optionsPaneV1: some View {
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
    var editions: some View {
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

    func dashed(_ text: String, color: Color = Theme.dim, centred: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(color)
            .multilineTextAlignment(centred ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}
