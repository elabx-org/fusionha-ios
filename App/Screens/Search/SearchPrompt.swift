/// The search field's placeholder. The web's long prompt fits the phone's
/// full-width field; wide (the open iPhone Duo, iPad) the field is narrower
/// than the page and cut it to "Search your library or add s…" (build 781).
enum SearchPrompt {
    static func text(requester: Bool, wide: Bool) -> String {
        if requester { return wide ? "Find a title to request" : "Find something to request…" }
        return wide ? "Search or add a title" : "Search your library or add something new…"
    }
}
