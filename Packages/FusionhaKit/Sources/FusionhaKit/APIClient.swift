import Foundation

public enum APIError: Error, LocalizedError, Sendable {
    case invalidServerURL
    case http(status: Int, body: String)
    case notSignedIn

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "That doesn't look like a server address."
        case .http(401, _), .http(403, _):
            return "The server rejected the sign-in."
        case .http(let status, _):
            return "The server answered with HTTP \(status)."
        case .notSignedIn:
            return "Not signed in."
        }
    }
}

/// How a signed-in client authenticates.
public enum AuthMethod: String, Codable, Sendable {
    /// A personal API token sent as `X-Api-Key` (preferred).
    case apiToken
    /// The 30-day session token sent as `Authorization: Bearer`, for accounts that
    /// lack the `tokens.manage.self` permission and so can't mint a personal token.
    case session
}

/// Thin async client over fusionha's `/api/v1`. Authenticates with a personal
/// API token (`X-Api-Key`) once signed in; sign-in itself uses the session cookie
/// that `POST /api/v1/auth/login` sets, which URLSession stores automatically.
public final class APIClient: @unchecked Sendable {
    public static let sessionCookieName = "fusionha_session"

    public let baseURL: URL
    private let token: String?
    private let authMethod: AuthMethod
    private let session: URLSession

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    public init(baseURL: URL, token: String?, method: AuthMethod = .apiToken, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.authMethod = method
        self.session = session
    }

    /// The session token from the cookie `POST /api/v1/auth/login` set, if any.
    public func sessionTokenFromCookie() -> String? {
        let cookies = session.configuration.httpCookieStorage?.cookies(for: baseURL) ?? []
        return cookies.first { $0.name == Self.sessionCookieName }?.value
    }

    /// Normalises user input like `192.168.1.10:8787` or `https://fusionha.example/`.
    public static func normalisedServerURL(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.host != nil else { return nil }
        return url
    }

    // MARK: Endpoints

    public func health() async throws -> HealthResponse {
        try await get("/health")
    }

    public func setupStatus() async throws -> SetupStatus {
        try await get("/api/v1/setup-status")
    }

    /// Starts Plex sign-in. The server binds the PIN to this client with a short-lived
    /// cookie, which URLSession keeps, so only this app can complete it.
    public func createPlexPin() async throws -> PlexPin {
        var req = request(method: "POST", path: "/api/v1/auth/plex/pin", query: [])
        // The server uses Origin to send Plex's page back to its own self-closing page.
        req.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        return try await perform(req)
    }

    /// Polls a Plex PIN. `202` means still pending; `200` means signed in (the server
    /// has set the session cookie). `403` means the Plex account isn't allowed here.
    public func checkPlexPin(id: Int) async throws -> PlexPinState {
        let req = request(method: "POST", path: "/api/v1/auth/plex/pin/\(id)/check", query: [])
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 202: return .pending
        case 200..<300: return .signedIn
        default: throw APIError.http(status: status, body: String(decoding: data.prefix(500), as: UTF8.self))
        }
    }

    public func login(username: String, password: String) async throws {
        let _: EmptyResponse = try await send(
            "POST", "/api/v1/auth/login", body: LoginRequest(username: username, password: password))
    }

    /// Mints a personal API token for this device. Its secret is only returned once.
    public func mintToken(name: String) async throws -> TokenMint {
        try await send("POST", "/api/v1/tokens", body: TokenCreate(name: name))
    }

    public func queue(pageSize: Int = 50) async throws -> QueuePage {
        try await get("/api/v1/queue", query: [URLQueryItem(name: "page_size", value: "\(pageSize)")])
    }

    public func library() async throws -> [MediaItem] {
        try await get("/api/v1/library")
    }

    public func wantedCounts() async throws -> WantedCounts {
        try await get("/api/v1/wanted", query: [URLQueryItem(name: "page_size", value: "1")])
    }

    public func calendar(start: Date, end: Date) async throws -> [CalendarEntry] {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return try await get("/api/v1/calendar", query: [
            URLQueryItem(name: "start", value: f.string(from: start)),
            URLQueryItem(name: "end", value: f.string(from: end)),
        ])
    }

    /// The decision-engine search. Note: this route has no `/api/v1` prefix on the server.
    public func searchItem(id: Int) async throws {
        let _: EmptyResponse = try await send("POST", "/library/\(id)/search", body: Optional<String>.none)
    }

    public func me() async throws -> Me {
        try await get("/api/v1/auth/me")
    }

    public func item(id: Int) async throws -> ItemDetail {
        try await get("/api/v1/library/\(id)")
    }

    public func wanted(state: WantedState, query: String? = nil, pageSize: Int = 100) async throws -> WantedPage {
        var items = [URLQueryItem(name: "state", value: state.rawValue),
                     URLQueryItem(name: "page_size", value: "\(pageSize)")]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await get("/api/v1/wanted", query: items)
    }

    public func history(query: String? = nil, pageSize: Int = 50) async throws -> HistoryPage {
        var items = [URLQueryItem(name: "page_size", value: "\(pageSize)")]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await get("/api/v1/history", query: items)
    }

    public func blocklist(query: String? = nil, pageSize: Int = 50) async throws -> BlocklistPage {
        var items = [URLQueryItem(name: "page_size", value: "\(pageSize)")]
        if let query, !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        return try await get("/api/v1/blocklist", query: items)
    }

    /// Searches TMDB (and the library) for titles to add.
    public func search(term: String, kind: SearchKind) async throws -> [MediaSearchResult] {
        try await get("/api/v1/search", query: [URLQueryItem(name: "term", value: term),
                                                URLQueryItem(name: "kind", value: kind.rawValue)])
    }

    public func discover(kind: SearchKind, list: DiscoverList, window: String = "week") async throws -> [MediaSearchResult] {
        try await get("/api/v1/discover", query: [URLQueryItem(name: "kind", value: kind.rawValue),
                                                  URLQueryItem(name: "list", value: list.rawValue),
                                                  URLQueryItem(name: "window", value: window)])
    }

    public func preview(kind: MediaKind, tmdbId: Int) async throws -> MediaPreview {
        try await get("/api/v1/preview/\(kind.rawValue)/\(tmdbId)")
    }

    public func requests() async throws -> [MediaRequest] {
        try await get("/api/v1/requests")
    }

    public func request(_ body: MediaRequestCreate) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/requests", body: body)
    }

    public func rootFolders() async throws -> [RootFolder] {
        try await get("/api/v1/rootfolders")
    }

    public func qualityProfiles() async throws -> [QualityProfile] {
        try await get("/api/v1/qualityprofiles")
    }

    public func addDefaults() async throws -> [AddDefaultSlot] {
        try await get("/api/v1/config/add-defaults")
    }

    public func add(_ body: LibraryAddRequest) async throws -> AddedItem {
        try await send("POST", "/api/v1/library", body: body)
    }

    public func searchMissing() async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/command/missing-search", body: Optional<String>.none)
    }

    public func searchCutoffUnmet() async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/command/cutoff-unmet-search", body: Optional<String>.none)
    }

    public func processQueue() async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/queue/process", body: Optional<String>.none)
    }

    // MARK: Transport

    struct EmptyResponse: Decodable {}

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await perform(request(method: "GET", path: path, query: query))
    }

    func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B?) async throws -> T {
        var req = request(method: method, path: path, query: [])
        if let body {
            req.httpBody = try Self.encoder.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await perform(req)
    }

    func request(method: String, path: String, query: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            switch authMethod {
            case .apiToken: req.setValue(token, forHTTPHeaderField: "X-Api-Key")
            case .session: req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        req.timeoutInterval = 20
        return req
    }

    func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(decoding: data.prefix(500), as: UTF8.self))
        }
        if T.self == EmptyResponse.self { return EmptyResponse() as! T }
        return try Self.decoder.decode(T.self, from: data)
    }
}
