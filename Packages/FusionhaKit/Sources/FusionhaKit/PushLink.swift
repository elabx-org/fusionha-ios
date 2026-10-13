import Foundation

/// Maps the web path a push carries (`url` in its payload) to the app's own
/// `fusionha://` deep link, so a tapped notification opens the same place it
/// would on the web (handoff §2, "Deep links from pushes"):
///
/// - `/library/{id}` → `fusionha://item/{id}`
/// - `/discover?tab=requests|issues` → `fusionha://discover/requests|issues`
/// - `/activity?tab=queue&focus=<downloadId>[&block=1]` → `fusionha://activity/queue?focus=<id>[&block=1]`
/// - `/activity?tab=audit` (the admin digest) → `fusionha://activity/audit`
public enum PushLink {
    public static func deepLink(webPath: String?) -> URL? {
        guard let webPath, let parts = URLComponents(string: webPath) else { return nil }
        let segments = parts.path.split(separator: "/").map(String.init)
        let query = Dictionary((parts.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        var link = URLComponents()
        link.scheme = "fusionha"
        switch segments.first {
        case "library":
            guard segments.count >= 2, let id = Int(segments[1]) else { return nil }
            link.host = "item"
            link.path = "/\(id)"
        case "discover":
            link.host = "discover"
            if let tab = query["tab"], ["browse", "requests", "issues"].contains(tab) { link.path = "/\(tab)" }
        case "activity":
            link.host = "activity"
            let tab = query["tab"] ?? "queue"
            guard ["queue", "history", "blocklist", "tasks", "audit", "indexers"].contains(tab) else { return nil }
            link.path = "/\(tab)"
            var items: [URLQueryItem] = []
            if let focus = query["focus"], Int(focus) != nil { items.append(URLQueryItem(name: "focus", value: focus)) }
            if query["block"] == "1", !items.isEmpty { items.append(URLQueryItem(name: "block", value: "1")) }
            if !items.isEmpty { link.queryItems = items }
        case "calendar", "wanted":
            link.host = segments[0]
        default:
            return nil
        }
        return link.url
    }

    /// `focus` / `block` from an activity link: the download to bring forward,
    /// and whether to open "Block release group?" on it.
    public static func queueFocus(in url: URL) -> (downloadId: Int, block: Bool)? {
        guard url.host() == "activity", let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let id = items.first(where: { $0.name == "focus" })?.value.flatMap(Int.init) else { return nil }
        return (id, items.contains { $0.name == "block" && $0.value == "1" })
    }
}
