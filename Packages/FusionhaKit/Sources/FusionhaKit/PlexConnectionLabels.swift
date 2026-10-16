import Foundation

// Pure copy + grouping for the Plex Server URL picker (web
// `plex-server/connection-labels.ts`). The backend classifies each address;
// this only words and groups it.

/// The revealed probe answers, by URI.
public typealias PlexProbeMap = [String: PlexConnectionProbe]

public enum PlexConnectionLabels {
    public static func kindText(_ kind: PlexConnectionKind) -> String {
        switch kind {
        case .lan: return "Your network"
        case .private: return "Private address"
        case .docker: return "Docker network"
        case .public: return "Public IP"
        case .domain: return "Custom domain"
        case .relay: return "Relay"
        }
    }

    /// "Custom domain · unencrypted" for a plain-http address.
    public static func kindLine(_ c: PlexConnection) -> String {
        kindText(c.kind) + (c.secure ? "" : " · unencrypted")
    }

    public struct Group: Sendable, Hashable, Identifiable {
        public let id: String
        public let title: String
        public let kinds: [PlexConnectionKind]
        public let note: String?
        public let collapsible: Bool
        public let avoid: Bool
    }

    public static let groups: [Group] = [
        Group(id: "lan", title: "Your network", kinds: [.lan, .private], note: nil, collapsible: false, avoid: false),
        Group(id: "remote", title: "Custom domains & remote", kinds: [.domain, .public], note: nil, collapsible: false, avoid: false),
        Group(id: "docker", title: "Docker networks", kinds: [.docker],
              note: "Container network addresses on your server. They can change when Docker restarts, so fusionha won't recommend them.",
              collapsible: true, avoid: true),
        Group(id: "relay", title: "Relay", kinds: [.relay], note: "Slow, bandwidth-limited — avoid.",
              collapsible: false, avoid: true),
    ]

    /// Answered as the owner's server: the only kind of address worth saving.
    public static func isUsable(_ r: PlexConnectionProbe?) -> Bool {
        guard let r else { return false }
        return r.reachable && r.isOwnerServer
    }

    public static func recReason(_ kind: PlexConnectionKind) -> String {
        switch kind {
        case .lan, .private:
            return "Fastest address fusionha can reach. A local address keeps library reads off the internet."
        case .relay:
            return "The only address that answered. Relays are slow and bandwidth-limited, so check your network or enter an address manually."
        default:
            return "Fastest address fusionha can reach. Library reads go over the internet, so a local address is better when there is one."
        }
    }

    public enum TailState: Sendable { case wait, ok, fail }

    public struct Tail: Sendable, Hashable {
        public let state: TailState
        public let text: String
        public let title: String?
    }

    /// A row's reachability tail: a dot state + "4 ms" / "no reply".
    public static func probeTail(_ r: PlexConnectionProbe?, testing: Bool = false) -> Tail {
        guard let r else { return Tail(state: .wait, text: testing ? "testing" : "—", title: nil) }
        if isUsable(r) { return Tail(state: .ok, text: "\(r.latencyMs ?? 0) ms", title: "Answered as your server") }
        switch r.error ?? "" {
        case "wrong_server":
            return Tail(state: .fail, text: "not your server", title: "A different Plex server answered here")
        case "http_error":
            return Tail(state: .fail, text: "answered, not Plex", title: "Something answered, but not as a Plex server")
        case "tls":
            return Tail(state: .fail, text: "certificate not trusted",
                        title: "The certificate is not trusted. For your own server with a self-signed certificate, turn off Verify TLS certificate below.")
        default:
            return Tail(state: .fail, text: "no reply", title: "fusionha got no reply from this address")
        }
    }

    /// "all reachable" / "all unreachable" / "2 reachable".
    public static func groupSummary(_ list: [PlexConnection], _ res: PlexProbeMap) -> String {
        let ok = list.filter { isUsable(res[$0.uri]) }.count
        if ok == list.count { return "all reachable" }
        if ok == 0 { return "all unreachable" }
        return "\(ok) reachable"
    }

    /// One "Other addresses" group with its rows.
    public struct GroupedConnections: Sendable, Hashable, Identifiable {
        public let group: Group
        public let list: [PlexConnection]
        public var id: String { group.id }
    }

    /// The "Other addresses" groups: everything but the recommendation, the
    /// reachable ones first (fastest first) within each group. Empty groups drop.
    public static func otherGroups(_ conns: [PlexConnection], _ res: PlexProbeMap,
                                   recUri: String?) -> [GroupedConnections] {
        func rank(_ c: PlexConnection) -> Int {
            guard let r = res[c.uri], isUsable(r) else { return Int.max }
            return r.latencyMs ?? 0
        }
        var out: [GroupedConnections] = []
        for group in groups {
            let indexed = conns.enumerated().filter { group.kinds.contains($0.element.kind) && $0.element.uri != recUri }
            let sorted = indexed.sorted { a, b in
                let ra = rank(a.element), rb = rank(b.element)
                return ra != rb ? ra < rb : a.offset < b.offset
            }
            if !sorted.isEmpty { out.append(GroupedConnections(group: group, list: sorted.map { $0.element })) }
        }
        return out
    }

    /// The host of a manually entered URL (port kept: it was typed), else as typed.
    public static func hostOf(_ url: String) -> String {
        guard let parts = URLComponents(string: url), let host = parts.host, !host.isEmpty else { return url }
        if let port = parts.port { return "\(host):\(port)" }
        return host
    }

    /// The collapsed summary: "Using 10.0.0.9 · your network · 4 ms", or
    /// "· entered manually" for an address Plex didn't report.
    public static func savedSummary(_ saved: String, _ conns: [PlexConnection],
                                    _ res: PlexProbeMap) -> (host: String, meta: String) {
        guard let c = conns.first(where: { $0.uri == saved }) else { return (hostOf(saved), "entered manually") }
        let r = res[c.uri]
        let ms = isUsable(r) ? " · \(r?.latencyMs ?? 0) ms" : ""
        return (c.label, kindText(c.kind).lowercased() + ms)
    }

    /// The order answers are revealed in: answering addresses first, fastest first.
    public static func arrivalOrder(_ results: [PlexConnectionProbe]) -> [PlexConnectionProbe] {
        let ok = results.filter { $0.reachable && $0.latencyMs != nil }.sorted { ($0.latencyMs ?? 0) < ($1.latencyMs ?? 0) }
        let okUris = Set(ok.map(\.uri))
        return ok + results.filter { !okUris.contains($0.uri) }
    }
}
