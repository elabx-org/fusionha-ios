import SwiftUI
import UIKit
import FusionhaKit

/// A lane's small-caps label: "IN YOUR LIBRARY  1", "EXACT MATCH  1".
struct SearchLaneLabel<Trailing: View>: View {
    let text: String
    let count: Int?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.dim)
            trailing
            Spacer(minLength: 8)
            if let count {
                Text("\(count)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, 14)
        .padding(.horizontal, Theme.pageGutter + 2)
        .padding(.bottom, 8)
    }
}

extension SearchLaneLabel where Trailing == EmptyView {
    init(text: String, count: Int?) {
        self.init(text: text, count: count) { EmptyView() }
    }
}

/// "AVAILABLE TO ADD · [TMDB][TVDB] ▾": the provider marks sit once, here
/// (option A), and the label is the source menu (All sources / TMDB /
/// TheTVDB), remembered on this device.
struct SearchSourceMenu: View {
    @Binding var filter: UnifiedSearchSourceFilter
    /// Providers that can answer (a provider without a key drops out).
    let available: [UnifiedSearchProvider]

    var body: some View {
        Menu {
            Picker("Sources", selection: $filter) {
                option(.all, "All sources", "TMDB + TheTVDB", marks: [.tmdb, .tvdb])
                option(.tmdb, "TMDB", "Movies, series, anime", marks: [.tmdb])
                option(.tvdb, "TheTVDB", "Series and anime", marks: [.tvdb])
            }
        } label: {
            HStack(spacing: 4) {
                Text("·").foregroundStyle(Theme.dim)
                ForEach(shownMarks, id: \.self) { mark($0) }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.dim)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sources: \(filter.title)")
    }

    private var shownMarks: [UnifiedSearchProvider] {
        let wanted: [UnifiedSearchProvider] = filter == .all ? [.tmdb, .tvdb] : (filter == .tmdb ? [.tmdb] : [.tvdb])
        let shown = wanted.filter { available.contains($0) }
        return shown.isEmpty ? wanted : shown
    }

    @ViewBuilder
    private func mark(_ provider: UnifiedSearchProvider) -> some View {
        switch provider {
        case .tmdb: TmdbLogo(size: 9, label: "TMDB")
        case .tvdb: TvdbLogo(size: 11, label: "TheTVDB")
        }
    }

    private func option(_ value: UnifiedSearchSourceFilter, _ title: String, _ note: String,
                        marks: [UnifiedSearchProvider]) -> some View {
        Label {
            Text(title)
            Text(note)
        } icon: {
            if let image = ProviderMarkImage.render(marks) {
                Image(uiImage: image)
            }
        }
        .tag(value)
    }
}

extension UnifiedSearchSourceFilter {
    var title: String {
        switch self {
        case .all: return "All sources"
        case .tmdb: return "TMDB"
        case .tvdb: return "TheTVDB"
        }
    }
}

/// The provider marks as a bitmap, for system menus (they only draw images).
/// Rendered in the active palette's appearance so TheTVDB picks its variant.
@MainActor
enum ProviderMarkImage {
    static func render(_ marks: [UnifiedSearchProvider]) -> UIImage? {
        let view = HStack(spacing: 3) {
            ForEach(marks, id: \.self) { mark in
                switch mark {
                case .tmdb: TmdbLogo(size: 9)
                case .tvdb: TvdbLogo(size: 11)
                }
            }
        }
        .environment(\.colorScheme, Theme.isLight ? .light : .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }
}
