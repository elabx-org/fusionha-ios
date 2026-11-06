import SwiftUI
import FusionhaKit

/// The decision card's plan (mock requests.js `plan`): an info glyph, then
/// what Approve does in one sentence, with what Not yet and Decline do after
/// it in the muted ink. Adjust (Approve with changes) sits at its end.
struct DecisionPlanLine: View {
    let sentence: DecisionPlan.Sentence
    var showsOverrides = true
    let canAdjust: Bool
    let onAdjust: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sentence.blocked ? Theme.mut : Theme.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                text
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if canAdjust {
                    Button("Approve with changes…", action: onAdjust)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentText)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private var text: Text {
        let approve = sentence.approve
        var line: Text
        if !sentence.blocked, approve.hasPrefix("Approve ") {
            line = Text("Approve").bold().foregroundColor(Theme.txt)
                + Text(approve.dropFirst("Approve".count)).foregroundColor(Theme.txt)
        } else {
            line = Text(approve).foregroundColor(sentence.blocked ? Theme.mut : Theme.txt)
        }
        if showsOverrides, let overrides = sentence.overrides {
            line = line + Text(" ") + Text(overrides).foregroundColor(Theme.mut)
        }
        return line
    }
}
