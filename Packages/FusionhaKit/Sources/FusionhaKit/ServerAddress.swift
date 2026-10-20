import Foundation

/// The first-run server step's forgiving input: what the person typed or
/// pasted, cleaned up, and the addresses worth trying for it. fusionha's
/// container listens on 8000 (`EXPOSE 8000`), so a bare LAN host also tries it.
public enum ServerAddress {
    public static let defaultPort = 8000

    /// Trims whitespace and quotes, and drops a web-app path or query someone
    /// pasted from the browser (`https://host/library?x=1` → `https://host`).
    /// A sub-path that isn't the web app's (a reverse-proxy prefix) is kept.
    public static func clean(_ input: String) -> String {
        var text = input.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'<>")))
        if let cut = text.firstIndex(where: { $0 == "?" || $0 == "#" }) { text = String(text[..<cut]) }
        let appRoutes = ["library", "discover", "calendar", "activity", "wanted", "requests", "settings", "login",
                         "search", "item", "account"]
        if let range = text.range(of: "://") {
            let afterScheme = text[range.upperBound...]
            if let slash = afterScheme.firstIndex(of: "/") {
                let path = afterScheme[afterScheme.index(after: slash)...]
                let first = path.split(separator: "/").first.map(String.init) ?? ""
                if appRoutes.contains(first.lowercased()) { text = String(text[..<slash]) }
            }
        } else if let slash = text.firstIndex(of: "/") {
            let first = text[text.index(after: slash)...].split(separator: "/").first.map(String.init) ?? ""
            if appRoutes.contains(first.lowercased()) { text = String(text[..<slash]) }
        }
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }

    /// Whether a change to the field looks like a paste rather than typing.
    public static func looksPasted(old: String, new: String) -> Bool {
        new.count - old.count >= 6 || (new.contains("://") && !old.contains("://"))
    }

    /// The addresses to try, best first. An explicit scheme is used as typed. A
    /// public domain tries https, then http. A LAN host or IP tries http, then
    /// fusionha's default port when none was given.
    public static func candidates(_ input: String) -> [URL] {
        let text = clean(input)
        guard !text.isEmpty else { return [] }
        if text.contains("://") {
            return APIClient.normalisedServerURL(text).map { [$0] } ?? []
        }
        guard let probe = URL(string: "http://" + text), let host = probe.host(), !host.isEmpty else { return [] }
        let hasPort = probe.port != nil
        var out: [String] = []
        if isLocal(host: host) {
            out.append("http://" + text)
            if !hasPort { out.append("http://\(host):\(defaultPort)\(probe.path)") }
        } else {
            out.append("https://" + text)
            out.append("http://" + text)
        }
        return out.compactMap(APIClient.normalisedServerURL)
    }

    /// A private, link-local or single-label host: one iOS asks Local Network
    /// permission for.
    public static func isLocal(host raw: String) -> Bool {
        let host = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".lan") || host.hasSuffix(".home.arpa") {
            return true
        }
        if !host.contains(".") && !host.contains(":") { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            switch (parts[0], parts[1]) {
            case (10, _), (127, _), (192, 168), (169, 254): return true
            case (172, 16...31): return true
            case (100, 64...127): return true
            default: return false
            }
        }
        if host.contains(":") {
            return host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80") || host == "::1"
        }
        return false
    }

    public static func isLocal(_ url: URL) -> Bool {
        url.host().map { isLocal(host: $0) } ?? false
    }

    /// The host as the person knows it, for "Recent: <host>" and the reached line.
    public static func label(_ url: URL) -> String {
        guard let host = url.host() else { return url.absoluteString }
        if let port = url.port { return "\(host):\(port)" }
        return host
    }
}
