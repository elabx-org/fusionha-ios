import Foundation

/// The one display formatter for season and episode numbers (arr and Plex
/// style, the web's `lib/episode-code.ts`): at least two digits (`01`, `09`,
/// `10`), a 3+ digit number keeps its width (`100`), specials read `S00`.
/// Display only: never parse or sort through these.
public enum EpisodeCode {
    /// `5` → `05`.
    public static func num(_ n: Int) -> String { n < 10 && n >= 0 ? "0\(n)" : "\(n)" }

    /// `S02` (specials `S00`).
    public static func season(_ season: Int) -> String { "S\(num(season))" }

    /// `S02·E03`, or `S02E03` with `separator: ""`.
    public static func episode(season: Int, episode: Int, separator: String = "·") -> String {
        "\(self.season(season))\(separator)E\(num(episode))"
    }

    /// `S01·E01–E06`; a one-episode range is just its code.
    public static func range(season: Int, first: Int, last: Int, separator: String = "·") -> String {
        let head = episode(season: season, episode: first, separator: separator)
        return first == last ? head : "\(head)–E\(num(last))"
    }

    /// An anime absolute number: `#05`, `#28`, `#1071`.
    public static func absolute(_ n: Int) -> String { "#\(num(n))" }
}
