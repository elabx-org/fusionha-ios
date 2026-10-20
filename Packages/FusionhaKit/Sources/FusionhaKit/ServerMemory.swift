import Foundation

/// A server this phone has connected to before, with the login look it had then
/// (so the next first screen can show that server's stage before connecting).
public struct RememberedServer: Codable, Equatable, Sendable, Identifiable {
    public var url: URL
    public var loginLayout: String?
    public var loginBackground: String?
    public var livingMedia: Bool?
    public var version: String?
    public var lastConnected: Date

    public var id: URL { url }
    public var label: String { ServerAddress.label(url) }

    public init(url: URL, loginLayout: String? = nil, loginBackground: String? = nil, livingMedia: Bool? = nil,
                version: String? = nil, lastConnected: Date = Date()) {
        self.url = url
        self.loginLayout = loginLayout
        self.loginBackground = loginBackground
        self.livingMedia = livingMedia
        self.version = version
        self.lastConnected = lastConnected
    }
}

/// What the server step may remember (fusionha #65): never a default server,
/// never a pre-filled field, never an auto-connect. Only servers this phone
/// actually reached, offered back as explicit "Recent" choices.
public struct ServerMemory {
    /// The old `@AppStorage` key that pre-filled the field; dropped, not migrated
    /// (it held whatever was typed, reached or not).
    public static let legacyAddressKey = "lastServer"
    static let recentsKey = "fusionha.recentServers"
    static let localNetworkKey = "fusionha.localNetworkExplained"
    /// `CredentialStore`'s key for the signed-in server.
    static let credentialServerKey = "serverURL"
    public static let maxRecents = 3

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The address field's starting text: always empty.
    public var initialAddress: String { "" }

    /// Servers reached before, most recent first.
    public var recents: [RememberedServer] {
        guard let data = defaults.data(forKey: Self.recentsKey),
              let list = try? JSONDecoder().decode([RememberedServer].self, from: data) else { return [] }
        return list.sorted { $0.lastConnected > $1.lastConnected }
    }

    /// The server a signed-in session points at, if any (none on a fresh install).
    public var storedServerURL: URL? {
        defaults.string(forKey: Self.credentialServerKey).flatMap(URL.init(string:))
    }

    public func remembered(_ url: URL) -> RememberedServer? {
        recents.first { $0.url == url }
    }

    /// Called only after `/health` and setup-status answered.
    public func remember(_ server: RememberedServer) {
        var list = recents.filter { $0.url != server.url }
        list.insert(server, at: 0)
        save(Array(list.prefix(Self.maxRecents)))
    }

    public func forget(_ url: URL) {
        save(recents.filter { $0.url != url })
    }

    /// Whether the Local Network line has been shown before a first LAN connect.
    public var localNetworkExplained: Bool {
        get { defaults.bool(forKey: Self.localNetworkKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.localNetworkKey) }
    }

    /// Drops the pre-#65 pre-fill value.
    public func dropLegacyAddress() {
        defaults.removeObject(forKey: Self.legacyAddressKey)
    }

    private func save(_ list: [RememberedServer]) {
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: Self.recentsKey) }
    }
}
