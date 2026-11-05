import SwiftUI
import FusionhaKit

/// Steps 2 and 3 of the decision panel (mock `vqDecision`): what happens
/// now, selected and in the accent, then every other answer as an override
/// that turns orange once chosen. Read-only for someone who may not manage
/// downloads.
struct DecisionChoices: View {
    let item: QueueItem
    @Binding var choice: HeldChoice
    let canDecide: Bool
    var dense = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DecisionStep(number: 2, title: "What happens now", tone: .accent, dense: dense)
            option(.stay)
            DecisionStep(number: 3, title: "Or choose", tone: .muted, dense: dense)
            ForEach(HeldChoice.overrides) { option($0) }
            if !canDecide {
                Text("Only someone who manages downloads can change this.")
                    .font(.footnote)
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 8)
            }
        }
    }

    private func option(_ value: HeldChoice) -> some View {
        let on = choice == value
        let tone: Color = value.isOverride ? Theme.stuck : Theme.primary
        return Button {
            choice = value
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle().strokeBorder(Theme.txt.opacity(0.32), lineWidth: 2).opacity(on ? 0 : 1)
                    Circle().fill(tone).opacity(on ? 1 : 0)
                    Circle().fill(.white).frame(width: 8, height: 8).opacity(on ? 1 : 0)
                }
                .frame(width: 22, height: 22)
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    tag(value, on: on)
                    Text(value.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Text(value.detail(item))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, dense ? 8 : 10)
            .background(tone.opacity(on ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? tone : Theme.txt.opacity(0.12), lineWidth: on ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(value.isOverride && !canDecide)
        .padding(.top, dense ? 6 : 7)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// "OVERRIDE" / "YOUR OVERRIDE" in the held ink; nothing on "stays held".
    @ViewBuilder
    private func tag(_ value: HeldChoice, on: Bool) -> some View {
        if value.isOverride {
            Text(on ? "YOUR OVERRIDE" : "OVERRIDE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Theme.stuckText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.stuck.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.bottom, 3)
        }
    }
}

/// A numbered step caption: "① WHAT’S WRONG".
struct DecisionStep: View {
    enum Tone { case held, accent, muted }
    let number: Int
    let title: String
    let tone: Tone
    var dense = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(ink)
                .frame(width: 20, height: 20)
                .background(fill, in: Circle())
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.mut)
        }
        .padding(.top, dense ? 12 : 16)
        .padding(.bottom, dense ? 1 : 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var fill: Color {
        switch tone {
        case .held: return Theme.stuck
        case .accent: return Theme.primary
        case .muted: return Theme.txt.opacity(0.55)
        }
    }

    private var ink: Color {
        switch tone {
        case .held: return Theme.onFill(hex: Theme.palette.stuck)
        case .accent: return Theme.onAccent
        case .muted: return Theme.bg
        }
    }
}
