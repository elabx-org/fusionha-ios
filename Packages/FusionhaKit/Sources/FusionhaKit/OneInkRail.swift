import Foundation

// v2 rails (owner 2026-11-04, mock rails.js): a bar means an amount
// (episodes, progress, space); whether you have a version is the badge beside
// it. One ink: on disk is the label colour, an empty track is missing, the
// accent is downloading, orange is held, and episodes not out yet are hollow.

public enum OneInkRail {
    /// What one stretch of a rail (or one episode tick) shows.
    public enum Piece: Equatable, Sendable {
        case onDisk, missing, downloading, held, unaired
    }

    /// One stretch of a capsule: its piece and its share of the width (0...1).
    public struct Span: Equatable, Sendable {
        public let piece: Piece
        public let fraction: Double

        public init(piece: Piece, fraction: Double) {
            self.piece = piece
            self.fraction = fraction
        }
    }

    /// One tick per episode up to this many; longer seasons use the capsule.
    public static let maxTicks = 26

    /// Counts clamped so 0 ≤ have ≤ aired ≤ total.
    public static func normalized(have: Int, aired: Int, total: Int) -> (have: Int, aired: Int, total: Int) {
        let total = max(0, total)
        let aired = min(total, max(0, aired))
        let have = min(aired, max(0, have))
        return (have, aired, total)
    }

    /// A season capsule: on disk, then the aired rest (`rest`: missing,
    /// downloading or held), then not out yet.
    /// Empty stretches are left out; an empty season has no spans.
    public static func spans(have: Int, aired: Int, total: Int, rest: Piece = .missing) -> [Span] {
        let n = normalized(have: have, aired: aired, total: total)
        guard n.total > 0 else { return [] }
        let t = Double(n.total)
        let parts: [(Piece, Int)] = [(.onDisk, n.have), (rest, n.aired - n.have), (.unaired, n.total - n.aired)]
        return parts.filter { $0.1 > 0 }.map { Span(piece: $0.0, fraction: Double($0.1) / t) }
    }

    /// One tick per episode, in order. Nil past `maxTicks` (use `spans`).
    public static func ticks(have: Int, aired: Int, total: Int, rest: Piece = .missing) -> [Piece]? {
        let n = normalized(have: have, aired: aired, total: total)
        guard n.total <= maxTicks else { return nil }
        return (0..<n.total).map { i in i < n.have ? .onDisk : i < n.aired ? rest : .unaired }
    }

    /// The rest piece for a version's badge state.
    public static func rest(for state: EditionBadgeState) -> Piece {
        switch state {
        case .downloading: return .downloading
        case .held: return .held
        default: return .missing
        }
    }

    /// "6 of 7": episodes on disk of those out.
    public static func countLine(have: Int, aired: Int) -> String {
        "\(max(0, have)) of \(max(0, aired))"
    }
}
