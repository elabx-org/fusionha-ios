import Foundation

/// A title's release-group blocks (the title page's Release groups sheet,
/// and "Block <GROUP>" on its search, file and history rows): which blocks
/// apply, how a scope goes on the wire, and the groups to suggest.
public enum TitleGroupBlocks {
    /// The scope for a block: `global` without a title, `item` with one.
    public static func scope(mediaItemId: Int?) -> String {
        mediaItemId == nil ? "global" : "item"
    }

    /// The `media_item_id` to send: none when the block is everywhere.
    public static func mediaItemId(everywhere: Bool, itemId: Int) -> Int? {
        everywhere ? nil : itemId
    }

    public static func isEverywhere(_ block: ReleaseGroupBlock) -> Bool {
        block.scope == "global" || block.mediaItemId == nil
    }

    /// "This title" or "Everywhere" (the words the web uses too).
    public static func scopeLabel(_ block: ReleaseGroupBlock) -> String {
        isEverywhere(block) ? "Everywhere" : "This title"
    }

    /// The server's group key (`decision/group_key.py`): compatibility
    /// forms folded, case folded, control and format characters dropped,
    /// separators trimmed from both ends, at most 64 characters. Nil when
    /// nothing alphanumeric is left.
    public static func key(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        let folded = name.precomposedStringWithCompatibilityMapping.lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
        let key = String(trimmed(visible(folded)).prefix(64))
        return key.contains(where: { $0.isLetter || $0.isNumber }) ? key : nil
    }

    /// The name as typed, without control characters or trimmed separators.
    public static func display(_ name: String?) -> String? {
        guard let name else { return nil }
        let shown = String(trimmed(visible(name)).prefix(64))
        return shown.isEmpty ? nil : shown
    }

    /// The blocks that apply to this title: its own first, then the global
    /// ones, newest first within each. Another title's blocks are dropped.
    public static func applying(_ blocks: [ReleaseGroupBlock], itemId: Int) -> [ReleaseGroupBlock] {
        let own = blocks.filter { !isEverywhere($0) && $0.mediaItemId == itemId }
        return own + blocks.filter(isEverywhere)
    }

    /// The block that stops `group` on this title, if any (its own before a global one).
    public static func block(for group: String?, in blocks: [ReleaseGroupBlock], itemId: Int) -> ReleaseGroupBlock? {
        guard let wanted = key(group) else { return nil }
        return applying(blocks, itemId: itemId).first { key($0.group) == wanted }
    }

    /// A search row the server rejected for its group ("Release group X is
    /// blocked for this title" / "… everywhere", `decision/reasons.py`).
    public static func isGroupBlockReason(_ reason: String?) -> Bool {
        guard let lower = reason?.lowercased() else { return false }
        return lower.hasPrefix("release group ") && lower.contains(" is blocked")
    }

    /// Groups seen on this title to offer under "Block a group": one per
    /// key (the first spelling seen), the most seen first, never one that is
    /// already blocked here, narrowed to those containing what was typed.
    public static func suggestions(seen: [String?], blocks: [ReleaseGroupBlock], itemId: Int,
                                   typed: String = "", limit: Int = 8) -> [String] {
        let blocked = Set(applying(blocks, itemId: itemId).compactMap { key($0.group) })
        let needle = key(typed)
        var order: [String] = []
        var spelling: [String: String] = [:]
        var count: [String: Int] = [:]
        for name in seen {
            guard let shown = display(name), let k = key(shown), !blocked.contains(k) else { continue }
            if let needle, !k.contains(needle) { continue }
            if spelling[k] == nil {
                spelling[k] = shown
                order.append(k)
            }
            count[k, default: 0] += 1
        }
        let ranked = order.enumerated().sorted { a, b in
            let (ca, cb) = (count[a.element] ?? 0, count[b.element] ?? 0)
            return ca != cb ? ca > cb : a.offset < b.offset
        }
        return ranked.prefix(limit).compactMap { spelling[$0.element] }
    }

    /// The list after a create: the returned row replaces one with its id
    /// (the server answers an existing block with 200), else leads the list.
    public static func merged(_ blocks: [ReleaseGroupBlock], adding block: ReleaseGroupBlock) -> [ReleaseGroupBlock] {
        [block] + blocks.filter { $0.id != block.id }
    }

    private static let strip = Set(" \t-_[](){}.")

    private static func visible(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter {
            $0.properties.generalCategory != .control && $0.properties.generalCategory != .format
        }))
    }

    private static func trimmed(_ text: String) -> Substring {
        let start = text.firstIndex { !strip.contains($0) } ?? text.endIndex
        let end = text.lastIndex { !strip.contains($0) }.map { text.index(after: $0) } ?? start
        return start < end ? text[start..<end] : ""
    }
}
