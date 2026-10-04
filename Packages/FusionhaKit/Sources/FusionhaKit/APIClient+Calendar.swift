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

    /// The subscribable feed, `{server}/api/v1/calendar/feed.ics?apikey=…`. The feed
    /// only accepts the app API key, not a personal token.
    public func calendarFeedURL(apiKey: String) -> URL? {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/calendar/feed.ics"),
                                             resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)]
        // URLQueryItem leaves `+` and `/` alone; encode like `encodeURIComponent`.
        let query = (components.percentEncodedQuery ?? "")
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "/", with: "%2F")
        components.percentEncodedQuery = query
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
