import SwiftUI
import FusionhaKit

/// The editor's Custom Formats pane: this kind's formats with a score each,
/// "Scored only" on by default, search across all of them, and the list sorted
/// by the current score as you edit. A score you set is marked Overridden (syncs
/// leave it alone); tap the mark to hand it back to the source.
struct QualityProfileFormatScoresPage: View {
    @Bindable var draft: QualityProfileDraft
    @State private var query = ""
    @State private var scoredOnly = true
    @Environment(\.settingsMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = draft.shownFormats(query: query, scoredOnly: scoredOnly)
        Form {
            Section {
                Toggle("Scored only", isOn: $scoredOnly).tint(Theme.i1)
            } footer: {
                Text("\(shown.count) shown\(scoredOnly && query.isEmpty ? " · scored" : "")")
            }
            Section {
                if draft.kindFormats.isEmpty {
                    Text(emptyCopy).font(.footnote).foregroundStyle(Theme.mut)
                } else if shown.isEmpty {
                    Text("No custom formats match.").font(.footnote).foregroundStyle(Theme.mut)
                } else {
                    ForEach(shown) { cf in
                        QualityProfileFormatScoreRow(draft: draft, format: cf)
                    }
                }
            }
        }
        .animation(motionOff || reduceMotion ? nil : .snappy, value: shown.map(\.id))
        .searchable(text: $query, prompt: "Search \(draft.kindFormats.count) custom formats…")
        // The title is the caller's: "Custom Formats" when pushed, the
        // editor's own when it is the wide sheet's trailing pane.
    }

    private var emptyCopy: String {
        if draft.fields.mediaKind == nil || draft.formats.isEmpty {
            return "No custom formats yet — add some to score releases."
        }
        return "No \(QualityProfileKinds.label(draft.fields.mediaKind)) custom formats yet — add some to score releases."
    }
}

/// One custom format: signed colour bar, name, Overridden mark and a − / +
/// stepper that steps ~5% of the current score (min 1).
struct QualityProfileFormatScoreRow: View {
    let draft: QualityProfileDraft
    let format: QualityProfileFormatOption

    var body: some View {
        let score = draft.live(format.id)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(score > 0 ? Theme.done : (score < 0 ? Theme.danger : Theme.line))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(format.name).font(.subheadline).foregroundStyle(Theme.txt).lineLimit(2)
                if draft.isOverride(format.id) {
                    Button("Overridden") { draft.release(format.id) }
                        .buttonStyle(.borderless)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.i2)
                        .accessibilityLabel("Overridden score for \(format.name). Tap to hand it back")
                        .accessibilityHint("Your score — syncs leave it alone.")
                }
            }
            Spacer(minLength: 4)
            TextField("Score for \(format.name)", text: Binding(get: { draft.scoreText(format.id) },
                                                                set: { draft.setScore(format.id, $0) }))
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 64)
            Stepper("Score for \(format.name)",
                    onIncrement: { draft.setScore(format.id, String(score + QualityProfileBody.step(score))) },
                    onDecrement: { draft.setScore(format.id, String(score - QualityProfileBody.step(score))) })
                .labelsHidden()
        }
    }
}
