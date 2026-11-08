import Foundation

extension APIClient {
    /// `GET /api/v1/settings` (the subset the Calendar reads).
    public func appSettings() async throws -> AppSettings {
        try await get("/api/v1/settings")
    }

    /// `PUT /api/v1/settings {"calendar_week_card_style": …}` (the Week card-style cog).
    public func setWeekCardStyle(_ style: WeekCardStyle) async throws {
        let _: EmptyResponse = try await send("PUT", "/api/v1/settings", body: WeekCardStylePatch(style))
    }

    /// `GET /api/v1/settings/api-key`: the app API key (admin only).
    public func appApiKey() async throws -> String {
        let key: AppApiKey = try await get("/api/v1/settings/api-key")
        return key.apiKey
    }

    /// The subscribable feed for this phone's server. Asks `GET /api/v1/calendar/feed-url`
    /// for the feed-only token (fusionha 0.4.244+) and keeps only that token: the server
    /// builds its `url` from the request, which behind a proxy can be an internal
    /// `http://host:port`, so the link always starts with this phone's server address.
    /// A server without the endpoint (404) still takes the app API key.
    public func calendarFeedLink() async throws -> URL {
        do {
            let link: CalendarFeedLink = try await get("/api/v1/calendar/feed-url")
            guard let token = Self.feedToken(in: link.url), let url = calendarFeedURL(token: token) else {
                throw APIError.invalidServerURL
            }
            return url
        } catch APIError.http(404, _) {
            let key = try await appApiKey()
            guard let url = calendarFeedURL(apiKey: key) else { throw APIError.invalidServerURL }
            return url
        }
    }

    /// The `token` query value of the server's feed `url`, whatever origin it carries.
    static func feedToken(in serverURL: String) -> String? {
        guard let items = URLComponents(string: serverURL)?.queryItems,
              let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty else { return nil }
        return token
    }

    /// `{server}/api/v1/calendar/feed.ics?token=…`.
    public func calendarFeedURL(token: String) -> URL? {
        feedURL(query: URLQueryItem(name: "token", value: token))
    }

    /// `{server}/api/v1/calendar/feed.ics?apikey=…`, for servers before 0.4.244.
    public func calendarFeedURL(apiKey: String) -> URL? {
        feedURL(query: URLQueryItem(name: "apikey", value: apiKey))
    }

    private func feedURL(query: URLQueryItem) -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/calendar/feed.ics"),
                                             resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [query]
        // URLQueryItem leaves `+` and `/` alone; encode like `encodeURIComponent`.
        let encoded = (components.percentEncodedQuery ?? "")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "/", with: "%2F")
        components.percentEncodedQuery = encoded
        return components.url
    }

    /// `GET /api/v1/calendar` for ISO days (`yyyy-MM-dd`).
    public func calendar(startISO: String, endISO: String) async throws -> [CalendarEntry] {
        try await get("/api/v1/calendar", query: [
            URLQueryItem(name: "start", value: startISO),
            URLQueryItem(name: "end", value: endISO),
        ])
    }
}
