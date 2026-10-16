import SwiftUI
import FusionhaKit

/// The editor's upgrade rules (the web's horizontal rules strip): Upgrades
/// allowed, Upgrade Until (the arr cutoff), the three custom-format score
/// thresholds and the Language filter, each with the web's help text.
struct QualityProfileRulesSection: View {
    @Bindable var draft: QualityProfileDraft

    var body: some View {
        Section("Upgrades") {
            Toggle(isOn: $draft.fields.upgradeAllowed) {
                FieldLabel(label: "Upgrades allowed",
                           description: "When on, better releases replace the file you already have.")
            }
            .tint(Theme.i1)
            Picker(selection: $draft.cutoffTag) {
                ForEach(draft.cutoffOptions, id: \.tag) { o in Text(o.label).tag(o.tag) }
            } label: {
                FieldLabel(label: "Upgrade Until",
                           description: "Once a file reaches this quality, no higher quality is grabbed. (This is the arr 'cutoff'.)")
            }
            .pickerStyle(.menu)
            QualityProfileScoreField(label: "Min CF Score",
                                     description: "Releases with a custom-format score below this are rejected outright.",
                                     text: $draft.fields.minScore)
            QualityProfileScoreField(label: "Upgrade Until CF Score",
                                     description: "Once this custom-format score is reached, no more upgrades are grabbed.",
                                     placeholder: "∞", text: $draft.fields.cutoffFormatScore)
                .disabled(!draft.fields.upgradeAllowed)
            QualityProfileScoreField(label: "Min CF Increment",
                                     description: "A new release must beat the current score by at least this much to count as an upgrade.",
                                     text: $draft.fields.minIncrement)
                .disabled(!draft.fields.upgradeAllowed)
        }
        Section {
            Picker(selection: $draft.fields.language) {
                Text("Original").tag("original")
                Text("Any").tag("any")
                Divider()
                ForEach(QualityProfileKinds.languages, id: \.self) { Text($0).tag($0) }
            } label: {
                FieldLabel(label: "Language")
            }
            .pickerStyle(.menu)
        } footer: {
            Text("Original rejects releases tagged in another language (the item's TMDB original language). Any accepts every language. A specific language pins it. Untagged, MULTI and dual-audio releases that include the wanted language are never rejected.")
        }
    }
}

/// A signed whole-number field kept as text, so a blank stays blank (the web's
/// `type=number` input).
struct QualityProfileScoreField: View {
    let label: String
    var description: String?
    var placeholder = ""
    @Binding var text: String
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        LabeledContent {
            TextField(label, text: $text, prompt: Text(placeholder))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .foregroundStyle(enabled ? Theme.txt : Theme.dim)
                .frame(width: 90)
        } label: {
            FieldLabel(label: label, description: description)
        }
    }
}
