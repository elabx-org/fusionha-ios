import SwiftUI
import FusionhaKit

/// How the results lay out: rows (default) or a poster grid. Remembered on
/// this device.
enum SearchLayout: String {
    case rows, grid

    static let storageKey = "unifiedSearch.layout"
}

/// v2's tools row above the results (search + Add mock v10, approved
/// 2026-11-10): the source switch All | TMDB | TheTVDB on the left, with the
/// official marks, and rows or grid on the right. Both are glass controls;
/// on the Duo the row sits in the band beside the column's arrow, so the
/// space above the first lane is used. Replaces the lane label's source menu.
struct SearchToolsRow: View {
    @Binding var filter: UnifiedSearchSourceFilter
    @AppStorage(SearchLayout.storageKey) private var layoutRaw = SearchLayout.rows.rawValue

    static let height: CGFloat = 44

    private var layout: SearchLayout { SearchLayout(rawValue: layoutRaw) ?? .rows }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    source(.all) { Text("All").font(.system(size: 13, weight: .semibold)) }
                    source(.tmdb) { TmdbLogo(size: 9) }
                    source(.tvdb) { TvdbLogo(size: 12) }
                }
                .padding(3)
                .glassEffect(.regular.interactive(), in: Capsule())
                Spacer(minLength: 8)
                HStack(spacing: 2) {
                    switchButton(.grid, symbol: "square.grid.2x2", label: "Grid")
                    switchButton(.rows, symbol: "list.bullet", label: "Rows")
                }
                .padding(3)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
        }
        .frame(height: Self.height)
    }

    private func source<Label: View>(_ value: UnifiedSearchSourceFilter, @ViewBuilder label: () -> Label) -> some View {
        let on = filter == value
        return Button { filter = value } label: {
            label()
                .foregroundStyle(on ? Theme.txt : Theme.mut)
                .opacity(on ? 1 : 0.7)
                .padding(.horizontal, 10)
                .frame(minWidth: 44)
                .frame(height: 30)
                .background(on ? Theme.txt.opacity(0.16) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func switchButton(_ value: SearchLayout, symbol: String, label: String) -> some View {
        let on = layout == value
        return Button { layoutRaw = value.rawValue } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Theme.txt : Theme.mut)
                .frame(width: 38, height: 30)
                .background(on ? Theme.txt.opacity(0.16) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// "AVAILABLE TO ADD · [TMDB][TVDB]" when the tools row picks the source:
/// the marks only say which providers answer, no menu.
struct SearchSourceMarks: View {
    let filter: UnifiedSearchSourceFilter
    let available: [UnifiedSearchProvider]

    var body: some View {
        HStack(spacing: 4) {
            Text("·").foregroundStyle(Theme.dim)
            ForEach(shown, id: \.self) { provider in
                switch provider {
                case .tmdb: TmdbLogo(size: 9)
                case .tvdb: TvdbLogo(size: 11)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("From \(filter.title)")
    }

    private var shown: [UnifiedSearchProvider] {
        let wanted: [UnifiedSearchProvider] = filter == .all ? [.tmdb, .tvdb] : (filter == .tmdb ? [.tmdb] : [.tvdb])
        let answered = wanted.filter { available.contains($0) }
        return answered.isEmpty ? wanted : answered
    }
}
