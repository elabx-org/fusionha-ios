import Foundation

/// What the Library home's "Coming up" row can show: three kinds of movie
/// release and three kinds of airing. Persisted as a comma list under a
/// v2-only key (`V2ComingUpSettings`).
enum V2ComingUpKind: String, CaseIterable, Identifiable {
    case digital, physical, cinemas
    case seriesPremiere, seasonPremiere, nextEpisode

    var id: Self { self }

    static let movies: [V2ComingUpKind] = [.digital, .physical, .cinemas]
    static let series: [V2ComingUpKind] = [.seriesPremiere, .seasonPremiere, .nextEpisode]

    /// The menu's toggle titles.
    var title: String {
        switch self {
        case .digital: return "Digital release"
        case .physical: return "Physical release"
        case .cinemas: return "In cinemas"
        case .seriesPremiere: return "New series premieres"
        case .seasonPremiere: return "Season premieres"
        case .nextEpisode: return "Next episodes"
        }
    }
}

/// The header menu's presets. A mix of toggles that matches none of them
/// reads "Custom".
enum V2ComingUpPreset: String, CaseIterable, Identifiable {
    case mix, movies, series

    var id: Self { self }

    var title: String {
        switch self {
        case .mix: return "Mix"
        case .movies: return "Movies only"
        case .series: return "Series only"
        }
    }

    var kinds: Set<V2ComingUpKind> {
        switch self {
        case .mix: return [.digital, .physical, .seriesPremiere, .seasonPremiere]
        case .movies: return Set(V2ComingUpKind.movies)
        case .series: return Set(V2ComingUpKind.series)
        }
    }

    /// The preset these toggles spell, if any.
    static func matching(_ kinds: Set<V2ComingUpKind>) -> V2ComingUpPreset? {
        allCases.first { $0.kinds == kinds }
    }
}

/// The row's persisted choice: v2-only `@AppStorage` keys and the comma
/// list the kinds are kept in.
enum V2ComingUpSettings {
    static let kindsKey = "v2.library.comingUp.kinds"
    static let daysKey = "v2.library.comingUp.days"
    static let windows = [7, 14, 30]
    static let defaultDays = 30
    static let defaultKinds = encode(V2ComingUpPreset.mix.kinds)

    static func decode(_ raw: String) -> Set<V2ComingUpKind> {
        Set(raw.split(separator: ",").compactMap { V2ComingUpKind(rawValue: String($0)) })
    }

    /// In menu order, so the stored string is stable.
    static func encode(_ kinds: Set<V2ComingUpKind>) -> String {
        V2ComingUpKind.allCases.filter { kinds.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    /// A window the menu offers (an old or hand-set value falls back to 30).
    static func window(_ days: Int) -> Int {
        windows.contains(days) ? days : defaultDays
    }
}
