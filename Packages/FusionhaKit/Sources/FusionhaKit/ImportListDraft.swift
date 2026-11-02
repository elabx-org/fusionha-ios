import Foundation

/// The Add / Edit import list form's values (web `use-import-list-form.ts`):
/// what Save sends and when it may.
public struct ImportListDraft: Sendable, Hashable {
    /// One tier's row: on or off, with its folder and profile (nil = Default Profiles).
    public struct Tier: Sendable, Hashable {
        public var on: Bool
        public var rootFolderId: Int?
        public var qualityProfileId: Int?

        public init(on: Bool, rootFolderId: Int? = nil, qualityProfileId: Int? = nil) {
            self.on = on
            self.rootFolderId = rootFolderId
            self.qualityProfileId = qualityProfileId
        }

        /// Not from Default Profiles.
        public var custom: Bool { rootFolderId != nil || qualityProfileId != nil }
    }

    public var url: String
    public var name: String
    public var mediaKind: ImportListMediaKind
    public var hd: Tier
    public var uhd: Tier
    public var monitored: Bool
    public var searchOnAdd: Bool
    public var intervalHours: Int
    public var enabled: Bool
    /// Editing an existing list: the address is read-only.
    public let editingId: Int?
    /// The list's site once known (the edited list's, or the preview's).
    public var provider: String?

    /// A new list: HD on, monitored, every 6 h, enabled.
    public init() {
        url = ""
        name = ""
        mediaKind = .movie
        hd = Tier(on: true)
        uhd = Tier(on: false)
        monitored = true
        searchOnAdd = false
        intervalHours = 6
        enabled = true
        editingId = nil
        provider = nil
    }

    public init(editing list: ImportList) {
        url = list.url
        name = list.name
        mediaKind = list.mediaKind
        func tier(_ t: QualityTier) -> Tier {
            list.version(t).map { Tier(on: true, rootFolderId: $0.rootFolderId, qualityProfileId: $0.qualityProfileId) } ?? Tier(on: false)
        }
        hd = tier(.hd)
        uhd = tier(.uhd)
        monitored = list.monitored
        searchOnAdd = list.searchOnAdd
        intervalHours = list.intervalHours
        enabled = list.enabled
        editingId = list.id
        provider = list.provider
    }

    public var editing: Bool { editingId != nil }
    public var trimmedURL: String { url.trimmingCharacters(in: .whitespaces) }
    public var isLetterboxd: Bool { provider?.uppercased() == "LETTERBOXD" }

    /// Letterboxd lists are read at most every 12 hours.
    public var effectiveInterval: Int {
        isLetterboxd ? max(intervalHours, ImportListCopy.letterboxdMinHours) : intervalHours
    }

    public func intervalAllowed(_ hours: Int) -> Bool {
        !isLetterboxd || hours >= ImportListCopy.letterboxdMinHours
    }

    public var versions: [ImportListVersion] {
        [(QualityTier.hd, hd), (.uhd, uhd)].compactMap { tier, t in
            t.on ? ImportListVersion(tier: tier, rootFolderId: t.rootFolderId, qualityProfileId: t.qualityProfileId) : nil
        }
    }

    /// At least one tier, and (adding) an address with no fatal preview problem.
    public func canSave(problemIsFatal: Bool) -> Bool {
        !versions.isEmpty && (editing || (!trimmedURL.isEmpty && !problemIsFatal))
    }

    private var common: [String: SettingsJSON] {
        ["versions": .array(versions.map(\.body)), "monitored": .bool(monitored),
         "search_on_add": .bool(searchOnAdd), "interval_hours": .int(effectiveInterval), "enabled": .bool(enabled)]
    }

    /// `POST /import-lists` (an empty name lets the server use the list's own).
    public var createBody: SettingsJSON {
        var body = common
        body["url"] = .string(trimmedURL)
        body["media_kind"] = .string(mediaKind.rawValue)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { body["name"] = .string(trimmed) }
        return .object(body)
    }

    /// `PATCH /import-lists/{id}` (the address and kind don't change).
    public func patchBody(fallbackName: String) -> SettingsJSON {
        var body = common
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        body["name"] = .string(trimmed.isEmpty ? fallbackName : trimmed)
        return .object(body)
    }
}
