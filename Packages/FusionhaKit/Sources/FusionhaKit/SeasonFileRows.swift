import Foundation

// The series Files tab, one row per episode file (owner-approved option 1):
// a season × version card lists its files in episode order, a file that
// holds two episodes is one row (`E25–26`), and a monitored, aired episode
// with no file keeps its place as a missing row.

/// One row of a season × version card.
public struct SeasonFileRow: Sendable, Hashable, Identifiable {
    /// The file, or nil for a missing episode.
    public let file: MovieFile?
    /// The episodes the file holds (one for a missing row), in number order.
    public let episodes: [Episode]

    public init(file: MovieFile?, episodes: [Episode]) {
        self.file = file
        self.episodes = episodes
    }

    public var id: String {
        if let file { return "f\(file.id)" }
        return "m\(episodes.first?.id ?? 0)"
    }

    public var isMissing: Bool { file == nil }

    /// `E01`, `E25–26`.
    public var label: String { EpisodeCode.fileEpisodes(episodes.map(\.episodeNumber)) }

    /// The episode title(s): one title, or both joined for a double episode.
    public var title: String {
        let titles = episodes.compactMap { $0.title }.filter { !$0.isEmpty }
        if titles.isEmpty { return episodes.count > 1 ? "Episodes \(label.dropFirst())" : "Episode \(label.dropFirst())" }
        return titles.joined(separator: " / ")
    }
}

extension EpisodeCode {
    /// The leading label of a file row: `E01`; a run `E25–26`; a file whose
    /// episodes are not consecutive lists them, `E01, 03`.
    public static func fileEpisodes(_ numbers: [Int]) -> String {
        let sorted = Array(Set(numbers)).sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if first == last { return "E\(num(first))" }
        if last - first == sorted.count - 1 { return "E\(num(first))–\(num(last))" }
        return "E" + sorted.map { num($0) }.joined(separator: ", ")
    }

    /// The sheet title: `S01E01`, `S01E25–26`.
    public static func fileCode(season: Int, episodes: [Int]) -> String {
        "\(self.season(season))\(fileEpisodes(episodes))"
    }
}

extension Season {
    /// The card's rows for one version: each file once, in the order of its
    /// first episode, with missing (monitored, aired, fileless) episodes in
    /// their place. An unmonitored season shows its files only.
    public func fileRows(editionId: Int, now: Date = Date()) -> [SeasonFileRow] {
        var files: [MovieFile] = []
        var episodesByFile: [Int: [Episode]] = [:]
        var order: [RowSeed] = []
        for ep in episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber }) {
            if let file = ep.file(for: editionId) {
                if episodesByFile[file.id] == nil {
                    files.append(file)
                    order.append(RowSeed(fileId: file.id, episode: ep))
                }
                episodesByFile[file.id, default: []].append(ep)
            } else if monitored != false, ep.monitored != false,
                      ep.status(editionId: editionId, now: now) == .missing {
                order.append(RowSeed(fileId: nil, episode: ep))
            }
        }
        return order.map { (entry: RowSeed) -> SeasonFileRow in
            guard let id = entry.fileId, let file = files.first(where: { $0.id == id }) else {
                return SeasonFileRow(file: nil, episodes: [entry.episode])
            }
            return SeasonFileRow(file: file, episodes: episodesByFile[id] ?? [entry.episode])
        }
    }

    private struct RowSeed {
        let fileId: Int?
        let episode: Episode
    }

    /// The card's subline: `26 of 26 episodes · 25 files`,
    /// `24 of 26 episodes · 2 missing`, or `3 files` with no monitored episodes.
    public func fileSummary(editionId: Int, fileCount: Int, now: Date = Date()) -> String {
        let files = "\(fileCount) file\(fileCount == 1 ? "" : "s")"
        let c = cover(editionId: editionId, now: now)
        guard c.total - c.unaired > 0 else { return files }
        let aired = c.total - c.unaired
        let head = "\(c.owned) of \(aired) episode\(aired == 1 ? "" : "s")"
        return c.wanted > 0 ? "\(head) · \(c.wanted) missing" : "\(head) · \(files)"
    }
}
