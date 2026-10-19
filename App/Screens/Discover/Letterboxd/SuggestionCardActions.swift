import SwiftUI
import FusionhaKit

/// The card's action area (web `SuggestionCard` actions + `RequestTierMenu`):
/// always visible on touch, never behind a hover.
struct SuggestionCardActions: View {
    let item: Suggestion
    let action: SuggestionRail.Action
    let uhdAllowed: Bool
    let working: Bool
    let request: ([QualityTier]) -> Void
    let meToo: () -> Void
    let more: () -> Void

    var body: some View {
        switch action {
        case .done(let done):
            Label(done.label, systemImage: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.done)
                .frame(minHeight: 32, alignment: .leading)
                .accessibilityElement(children: .combine)
        case .meToo(let asked):
            VStack(alignment: .leading, spacing: 6) {
                Button("Me too", action: meToo)
                    .buttonStyle(.discover(.subtle, fullWidth: true))
                    .disabled(working)
                    .accessibilityLabel("Me too · \(item.title)")
                    .accessibilityHint(SuggestionRail.meTooHint)
                Text(SuggestionRail.askedLine(asked))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
            }
        case .request(let overLimit):
            HStack(spacing: 4) {
                Button(SuggestionRail.primaryLabel(overLimit: overLimit)) { request([.hd]) }
                    .buttonStyle(SuggestionPrimaryStyle())
                    .accessibilityLabel("\(SuggestionRail.primaryLabel(overLimit: overLimit)) · \(item.title)")
                tierMenu
            }
            .disabled(working)
        }
    }

    private var tierMenu: some View {
        Menu {
            ForEach(SuggestionRail.tierOptions(uhdAllowed: uhdAllowed), id: \.self) { option in
                Button(option.label) { request(option.tiers) }
            }
            if !uhdAllowed {
                Text(SuggestionRail.uhdUnavailable)
            }
            Divider()
            Button(SuggestionRail.moreOptions, action: more)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.txt)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("Request options · \(item.title)")
    }
}

/// The card's narrow primary capsule (`.acts > button:first-child`: tight
/// side padding so "Add to wishlist" fits beside the caret).
private struct SuggestionPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.onAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.92)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Theme.primary, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .contentShape(Capsule())
    }
}
