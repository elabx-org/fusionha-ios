import SwiftUI
import FusionhaKit

// Shared pieces for Settings › Custom Formats and › TRaSH Guides: the pushed
// sub-page shell, provenance / kind tags, and signed score text.

/// A pushed sub-page (catalog, import, tester, a TRaSH section): the panels'
/// dark Form without the panel title block.
struct FormatsSubpage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
    }
}

/// The provenance badge: only imported formats are tagged (manual shows nothing).
struct CfSourceBadge: View {
    let source: String

    var body: some View {
        if let tint {
            Text(source)
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(tint.opacity(0.14), in: Capsule())
                .fixedSize()
        }
    }

    private var tint: Color? {
        switch source {
        case "trash": return Theme.i1
        case "arr": return Theme.grab
        case "preset": return Theme.done
        default: return nil
        }
    }
}

/// `MV` / `SR` / `AN`, tinted per kind; nothing for a legacy no-kind format.
struct CfKindTag: View {
    let kind: String?

    var body: some View {
        if let tag = CFLibrary.kindTag(kind) {
            Text(tag)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(color.opacity(0.6)))
                .fixedSize()
                .accessibilityLabel("\(kind ?? "") kind")
        }
    }

    private var color: Color {
        switch kind {
        case "series": return Theme.kindSeries
        case "anime": return Theme.kindAnime
        default: return Theme.kindMovie
        }
    }
}

/// A matched format chip: name + signed score, red when negative.
struct CfScoreChip: View {
    let name: String
    let score: Int
    var highlighted = false

    var body: some View {
        HStack(spacing: 4) {
            Text(name).lineLimit(1)
            Text(CFLibrary.score(score)).font(.system(size: 10.5, weight: .bold).monospacedDigit())
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(score < 0 ? Theme.danger : Theme.done)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background((score < 0 ? Theme.danger : Theme.done).opacity(highlighted ? 0.26 : 0.12), in: Capsule())
        .fixedSize()
    }
}

/// `+1750` in green, `-10000` in red, `0` muted.
struct CfSignedScore: View {
    let score: Int

    var body: some View {
        Text(score > 0 ? "+\(score)" : "\(score)")
            .font(.system(size: 12.5, weight: .bold).monospacedDigit())
            .foregroundStyle(score > 0 ? Theme.done : (score < 0 ? Theme.danger : Theme.mut))
    }
}

/// The Movies / Series / Anime segmented picker shared by the TRaSH sections.
struct TrashMediaPicker: View {
    @Binding var category: TrashCategory
    var counts: [TrashCategory: Int] = [:]

    var body: some View {
        Picker("Media", selection: $category) {
            ForEach(TrashCategory.allCases) { c in
                Text(counts[c].map { "\(c.label) \($0)" } ?? c.label).tag(c)
            }
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

/// A one-line inline error under a form action.
struct FormatsErrorRow: View {
    let message: String

    var body: some View {
        Text(message).font(.footnote).foregroundStyle(Theme.danger)
    }
}
