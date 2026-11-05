import SwiftUI
import FusionhaKit

/// The Library's no-match state (mock browse-lib.js `nomatch`): a search
/// glyph, what didn't match, then "Search everything" (the words go to the
/// Search tab, which also looks in TMDB, TheTVDB and TVmaze) and Clear.
/// Without words it is the filters that left nothing, so only Clear.
struct V2LibraryNoMatch: View {
    let query: String
    /// "series", "movies", "titles": the kind in view.
    let noun: String
    /// The titles in that kind before the filters.
    let total: Int
    let clear: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .accessibilityHidden(true)
            Text(query.isEmpty ? "No \(noun) match these filters" : "No \(noun) match your search")
                .font(.title3.weight(.semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            // The mock's 40pt buttons (`K.btn(…, { h: 40 })`): glass drawn on
            // a fixed label, since a glass button style pads it past 40.
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    if !query.isEmpty {
                        Button {
                            model.searchQuery = query
                            model.tab = .search
                        } label: {
                            buttonLabel(Label("Search everything", systemImage: "globe"))
                                .foregroundStyle(Theme.onAccent)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(Theme.primary).interactive(), in: Capsule())
                    }
                    Button(action: clear) {
                        buttonLabel(Text("Clear")).foregroundStyle(Theme.txt)
                    }
                    .buttonStyle(.plain)
                    .glassControl()
                }
            }
            .padding(.top, 16)
            if !query.isEmpty {
                Text("Everything also looks in TMDB, TheTVDB and TVmaze")
                    .font(.caption)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
        .padding(.bottom, 40)
    }

    private func buttonLabel(_ content: some View) -> some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .contentShape(Capsule())
    }

    private var detail: String {
        if query.isEmpty { return "Try another version, or clear the filters to see all \(total.formatted()) \(noun)." }
        return "Nothing in your \(total.formatted()) \(noun) is called “\(query)”."
    }
}
