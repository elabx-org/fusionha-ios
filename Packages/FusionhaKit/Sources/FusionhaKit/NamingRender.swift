import Foundation

extension NamingFormat {
    /// The client-side mirror of `services/naming.py` for one path component
    /// (web `renderSegments`): `{Token}` / `{Token:0N}` substitution against the
    /// sample (case-insensitive names; an unknown or empty token renders the
    /// whole group, in-brace separators included, empty), optional illegal-
    /// character replacement, empty `[]` / `()` collapse and whitespace cleanup.
    public static func render(_ format: String, sample: [String: String], replaceIllegal: Bool) -> [NamingSegment] {
        var lookup: [String: String] = [:]
        for (k, v) in sample { lookup[k.lowercased()] = v }
        let collapsed = collapseEmptyGroups(format, lookup: lookup)
        let merged = merge(substitute(collapsed, lookup: lookup))
        return cleanup(merged, replaceIllegal: replaceIllegal)
    }

    /// The whole preview line as plain text (tests and accessibility).
    public static func plain(_ segments: [NamingSegment]) -> String {
        segments.map(\.text).joined()
    }

    /// Drop `{edition-{Edition Tags}}`-style groups whose inner token is empty.
    static func collapseEmptyGroups(_ format: String, lookup: [String: String]) -> String {
        let ns = format as NSString
        var out = format
        let matches = nestedRegex.matches(in: format, range: NSRange(location: 0, length: ns.length))
        for m in matches.reversed() {
            let inner = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces).lowercased()
            let value = lookup[inner] ?? ""
            if value.isEmpty, let r = Range(m.range, in: out) {
                out.replaceSubrange(r, with: "")
            }
        }
        return out
    }

    static func substitute(_ format: String, lookup: [String: String]) -> [NamingSegment] {
        let ns = format as NSString
        var raw: [NamingSegment] = []
        var last = 0
        for m in tokenRegex.matches(in: format, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                raw.append(NamingSegment(text: ns.substring(with: NSRange(location: last, length: m.range.location - last))))
            }
            let prefix = group(m, 1, ns)
            let name = group(m, 2, ns).trimmingCharacters(in: .whitespaces)
            let pad = m.range(at: 3).location == NSNotFound ? nil : group(m, 3, ns)
            let suffix = group(m, 4, ns)
            if let value = lookup[name.lowercased()], !value.isEmpty {
                if !prefix.isEmpty { raw.append(NamingSegment(text: prefix)) }
                raw.append(NamingSegment(text: padded(value, pad), kind: tokenKind(name)))
                if !suffix.isEmpty { raw.append(NamingSegment(text: suffix)) }
            }
            last = m.range.location + m.range.length
        }
        if last < ns.length { raw.append(NamingSegment(text: ns.substring(from: last))) }
        return raw
    }

    private static func group(_ m: NSTextCheckingResult, _ i: Int, _ ns: NSString) -> String {
        let r = m.range(at: i)
        return r.location == NSNotFound ? "" : ns.substring(with: r)
    }

    /// `naming.py` pads via `int(value)` when the token carries `:0N`.
    static func padded(_ value: String, _ pad: String?) -> String {
        guard let pad else { return value }
        let ns = value as NSString
        guard intLike.firstMatch(in: value, range: NSRange(location: 0, length: ns.length)) != nil,
              let n = Int(value.trimmingCharacters(in: .whitespaces)) else { return value }
        let digits = String(n)
        return digits.count >= pad.count ? digits : String(repeating: "0", count: pad.count - digits.count) + digits
    }

    /// Join literal runs that empty tokens left adjacent.
    static func merge(_ raw: [NamingSegment]) -> [NamingSegment] {
        var merged: [NamingSegment] = []
        for seg in raw {
            if let prev = merged.last, prev.kind == nil, seg.kind == nil {
                merged[merged.count - 1].text += seg.text
            } else {
                merged.append(seg)
            }
        }
        return merged
    }

    static func cleanup(_ merged: [NamingSegment], replaceIllegal: Bool) -> [NamingSegment] {
        var cleaned: [NamingSegment] = merged.compactMap { (seg: NamingSegment) -> NamingSegment? in
            var text = seg.text
            if replaceIllegal {
                for (bad, good) in illegal { text = text.replacingOccurrences(of: bad, with: good) }
            }
            if seg.kind == nil {
                text = text.replacingOccurrences(of: "[]", with: "").replacingOccurrences(of: "()", with: "")
                let ns = text as NSString
                text = spaces.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length),
                                                       withTemplate: " ")
            }
            return text.isEmpty ? nil : NamingSegment(text: text, kind: seg.kind)
        }
        if !cleaned.isEmpty {
            cleaned[0].text = String(cleaned[0].text.drop(while: { $0.isWhitespace }))
            let end = cleaned.count - 1
            while let lastChar = cleaned[end].text.last, lastChar.isWhitespace { cleaned[end].text.removeLast() }
        }
        return cleaned.filter { !$0.text.isEmpty }
    }
}
