import Foundation

// MARK: - The playful voice (web `lib/voice/quip.ts`)
//
// When `voice_playful` is on, a surface may add a media one-liner after its
// facts. Deterministic: the line is picked by an FNV-1a hash of
// `title|outcome`, so the same title always gets the same line, on the web and
// here. Every line is an original homage, never a verbatim quote.

public enum VoiceQuip {
    public enum Kind: Sendable { case movie, series, anime }
    public enum Outcome: String, Sendable { case grabbed, upgraded, noRelease = "no_release", updated, failed, running }
    enum Flavor { case failure, spice, anime, generic }

    static let pools: [Flavor: [String]] = [
        .failure: [
            "The indexer left us on read.",
            "Ghosted by the indexer — we will try again.",
            "That release slipped right through our fingers.",
            "No answer from the other side; we will circle back.",
            "The download gods were not listening today.",
        ],
        .spice: [
            "The spice flows your way.",
            "Harvested straight off the dunes.",
            "The spice stays put — you already hold the best there is.",
            "Planned down to the last grain of sand.",
            "The desert gave up its treasure.",
        ],
        .anime: [
            "Absolute number matched — absolute certainty.",
            "The sub group came through on release day.",
            "Canon secured, filler left behind.",
            "One episode closer to the finale — called it.",
            "Never doubted the release group for a second.",
        ],
        .generic: [
            "Found it. We always find it.",
            "Winter came early — and it brought loot.",
            "New intel, decrypted.",
            "Consider it handled.",
            "Right where I expected it.",
            "Logged, sorted, and dealt with.",
            "The library remembers this one.",
            "No wasted motion.",
        ],
    ]

    static func flavor(kind: Kind, title: String, outcome: Outcome) -> Flavor {
        if outcome == .failed { return .failure }
        if title.range(of: #"\b(dune|arrakis|spice)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .spice
        }
        if kind == .anime && (outcome == .grabbed || outcome == .upgraded) { return .anime }
        return .generic
    }

    /// FNV-1a over UTF-16 code units (JavaScript's `charCodeAt`), unsigned 32-bit.
    static func hashIndex(_ seed: String, _ count: Int) -> Int {
        var h: UInt32 = 0x811c_9dc5
        for unit in seed.utf16 {
            h ^= UInt32(unit)
            h = h &* 0x0100_0193
        }
        return Int(h % UInt32(count))
    }

    /// `mediaSuffix`: the raw one-liner (no facts, no separator).
    public static func mediaSuffix(kind: Kind, title: String, outcome: Outcome) -> String {
        let pool = pools[flavor(kind: kind, title: title, outcome: outcome)] ?? []
        guard !pool.isEmpty else { return "" }
        return pool[hashIndex("\(title)|\(outcome.rawValue)", pool.count)]
    }
}
