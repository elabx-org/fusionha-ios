import Foundation

// Monochrome's status language (fusionha 0.4.221: `status.ts` statusPattern /
// statusGlyph and the Monochrome block of `palettes.gen.css`). With no hue to
// lean on, a status reads as a shade, a fill pattern and a glyph. Every other
// palette ignores this (the web's `--pat-*` / `--g-*` tokens are empty there).

/// A status colour token (`--done`, `--grab`, ...): what `status.ts` maps a status onto.
public enum MonoToken: String, CaseIterable, Sendable, Hashable {
    case done, grab, miss, unaired, unmonitored, onair, premiere, stuck, edition, anime, danger

    /// `--pat-<token>` under Monochrome. Done and danger are a plain fill.
    public var pattern: MonoPattern {
        switch self {
        case .done, .danger: return .none
        case .grab: return .diag
        case .miss: return .horiz
        case .unaired: return .dots
        case .unmonitored: return .vert
        case .onair: return .cross
        case .premiere: return .check
        case .stuck: return .anti
        case .edition: return .dense
        case .anime: return .wave
        }
    }

    /// `--g-<token>`: the web's text glyph.
    public var glyph: String {
        switch self {
        case .done: return "\u{2713}"
        case .grab: return "\u{2193}"
        case .miss: return "\u{25CB}"
        case .unaired: return "\u{2026}"
        case .unmonitored: return "\u{2013}"
        case .onair: return "\u{25CF}"
        case .premiere: return "\u{2605}"
        case .stuck: return "\u{25B2}"
        case .edition: return "\u{25C6}"
        case .anime: return "\u{2726}"
        case .danger: return "\u{2715}"
        }
    }

    /// The SF Symbol drawing `glyph` (✓ ↓ ○ … – ● ★ ▲ ◆ ✦ ✕).
    public var symbol: String {
        switch self {
        case .done: return "checkmark"
        case .grab: return "arrow.down"
        case .miss: return "circle"
        case .unaired: return "ellipsis"
        case .unmonitored: return "minus"
        case .onair: return "circle.fill"
        case .premiere: return "star.fill"
        case .stuck: return "triangle.fill"
        case .edition: return "diamond.fill"
        case .anime: return "sparkle"
        case .danger: return "xmark"
        }
    }

    /// The token's grey under Monochrome (0–255, `palettes.gen.css`). The app
    /// paints the palette's own token; this mirrors it for the rule's tests.
    public var monoShade: UInt8 {
        switch self {
        case .done, .grab, .edition, .danger: return 0xF2
        case .miss: return 0xBD
        case .unaired: return 0xD9
        case .unmonitored: return 0x70
        case .onair: return 0xE0
        case .premiere, .anime: return 0xD0
        case .stuck: return 0xCF
        }
    }
}

/// The Monochrome fill patterns (`--p-*` in `tokens.css`): 4pt tiles, 3pt for dense.
public enum MonoPattern: String, CaseIterable, Sendable, Hashable {
    case none, diag, anti, horiz, vert, dots, dense, cross, check, wave

    /// The tile edge in points.
    public var cell: Double { self == .dense ? 3 : 4 }
}

extension EditionStatus {
    /// `STATUS_META[...].token`.
    public var monoToken: MonoToken {
        switch self {
        case .downloaded: return .done
        case .downloading, .available: return .grab
        case .upgrading: return .edition
        case .missing, .deadlink: return .miss
        case .unaired, .upcoming: return .unaired
        case .unmonitored, .other: return .unmonitored
        case .onair: return .onair
        case .premiere: return .premiere
        case .stuck: return .stuck
        }
    }
}

extension RailState {
    /// The web's RAIL_STATUS map onto a token.
    public var monoToken: MonoToken {
        switch self {
        case .owned: return .done
        case .partial, .wanted: return .miss
        case .downloading: return .grab
        case .upgrading: return .edition
        case .upcoming: return .unaired
        }
    }
}

extension CardStatus {
    /// `CARD_STATUS_KEY` onto a token.
    public var monoToken: MonoToken {
        switch self {
        case .downloading: return .grab
        case .missing: return .miss
        case .upcoming: return .unaired
        case .complete: return .done
        }
    }
}

extension QualityTier {
    /// `--tier-chip-hd` / `--tier-chip-uhd` under Monochrome: HD light, 4K mid grey.
    public var monoShade: UInt8 { self == .hd ? 0xD9 : 0x8C }
    /// The tier's status token off Monochrome (HD purple = edition, 4K cyan = grab).
    public var monoToken: MonoToken { self == .hd ? .edition : .grab }
}

/// The Wanted wire's per-edition state (`missing` / `cutoff_unmet` / `upcoming`).
public enum WantedStateToken {
    public static func token(_ state: String) -> MonoToken {
        switch state {
        case "missing": return .miss
        case "cutoff_unmet": return .edition
        case "upcoming": return .unaired
        default: return .done
        }
    }
}
