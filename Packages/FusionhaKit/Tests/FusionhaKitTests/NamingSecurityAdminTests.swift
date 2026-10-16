import XCTest
@testable import FusionhaKit

final class NamingSecurityAdminTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func render(_ format: String, _ kind: NamingKind, illegal: Bool = true) -> String {
        NamingFormat.plain(NamingFormat.render(format, sample: NamingFormat.previewSample(kind), replaceIllegal: illegal))
    }

    // MARK: Naming

    func testSonarrAcceptanceFormatRendersByteExact() {
        let format = "{Series TitleYear} - S{season:00}E{episode:00} - {Episode CleanTitle} "
            + "[{Custom Formats }{Quality Full}]{[MediaInfo VideoDynamicRangeType]}"
            + "{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{[MediaInfo VideoCodec]}{-Release Group}"
        XCTAssertEqual(render(format, .series),
                       "FROM (2022) - S04E01 - The Arrival [AMZN WEBDL-1080p][EAC3 5.1][h264]-FLUX")
    }

    func testUnknownTokenSwallowsItsSeparator() {
        XCTAssertEqual(render("{Series Title} - S{season:00}E{episode:00}{-Not A Token}", .series), "FROM - S04E01")
    }

    func testSeriesNeverPreviewsTheEditionGroup() {
        XCTAssertEqual(render("X {edition-{Edition Tags}} [{Quality Full}]", .series), "X [WEBDL-1080p]")
    }

    func testMovieEditionGroupKeepsItsBraces() {
        XCTAssertEqual(render("{Movie Title} {edition-{Edition Tags}} [{Quality Full}]", .movie),
                       "Dune Part Two {edition-Director's Cut} [Bluray-2160p Remux]")
    }

    func testIllegalCharactersAndPadding() {
        XCTAssertEqual(render("{Movie Title}: {Release Year}", .movie), "Dune Part Two - 2024")
        XCTAssertEqual(render("{Movie Title}: {Release Year}", .movie, illegal: false), "Dune Part Two: 2024")
        XCTAssertEqual(render("{Series Title} - {absolute:000}", .anime), "Frieren - 028")
    }

    func testSegmentKinds() {
        let segs = NamingFormat.render("{Movie Title} [{Quality Full}] {Custom Formats}",
                                       sample: NamingFormat.sample(.movie), replaceIllegal: true)
        XCTAssertEqual(segs.map(\.kind), [.title, nil, .quality, nil, .customFormat])
        XCTAssertEqual(segs.map(\.text), ["Dune Part Two", " [", "Bluray-2160p Remux", "] ", "DV HDR10+ TrueHD ATMOS"])
    }

    func testPaletteIsScopedToKind() {
        XCTAssertTrue(NamingFormat.tokens(.movie).contains("{edition-{Edition Tags}}"))
        XCTAssertFalse(NamingFormat.tokens(.series).contains("{edition-{Edition Tags}}"))
        XCTAssertTrue(NamingFormat.tokens(.anime).contains("{absolute:000}"))
        XCTAssertFalse(NamingFormat.tokens(.series).contains("{Movie Title}"))
    }

    func testEmptyAnimeFormatFallsBack() {
        let values = ["standard_episode_format": "EP", "standard_anime_episode_format": "",
                      "series_folder_format": "S", "season_folder_format": "N"]
        let formats = NamingFormat.previewFormats(.anime) { values[$0] ?? "" }
        XCTAssertEqual(formats.folders, ["S", "N"])
        XCTAssertEqual(formats.file, "EP")
    }

    // MARK: Security

    private func status(state: String = "ok", encrypted: Int = 3, plaintext: Int = 0,
                        unreadable: String = "[]", rotation: String = "null", pass: Bool = false) -> String {
        """
        {"encrypted": true, "plaintext_remaining": \(plaintext), "unreadable": \(unreadable),
         "key_fingerprint": "3f9a1c0be27d5a46", "key_source": "file", "state": "\(state)", "reason": null,
         "encrypted_count": \(encrypted), "encrypt_pass": {"running": \(pass), "done": 1, "total": 4},
         "rotation": \(rotation), "key_path": "/data/secret.key",
         "retired_keys": [{"fingerprint": "aaaabbbbccccdddd", "retired_at": "2026-10-01T09:12:00"}],
         "backup_include_secret_key": false, "legacy_backups": 2, "first_run": false,
         "key_created_at": "2026-10-13T09:12:00.123456", "found_fingerprint": null,
         "integrations": {"indexers": ["A", "B"], "download_clients": ["SABnzbd"], "virtual_instances": [],
           "notification_agents": [], "connect_webhooks": [], "arr_connections": []},
         "recovery_key_stale": true}
        """
    }

    func testStatusDecodesAndSummarises() throws {
        let s = try decode(SecretsStatus.self, status())
        XCTAssertEqual(s.tone, .ok)
        XCTAssertEqual(s.retiredKeys.first?.retiredAt, "2026-10-01T09:12:00")
        XCTAssertEqual(s.integrations?.downloadClients, ["SABnzbd"])
        XCTAssertEqual(s.hero.title, "All 3 secrets are encrypted at rest")
        XCTAssertEqual(s.hero.sub, "Passwords, API keys and tokens for 2 indexers and 1 download client, plus app settings such as the TMDB key.")
        XCTAssertNil(s.rotateBlockedReason)
        XCTAssertEqual(s.sourceLabel, "Key file")
    }

    func testBusyAndLockedStates() throws {
        let rotating = try decode(SecretsStatus.self, status(
            state: "rotating", rotation: #"{"running": true, "done": 2, "total": 4}"#))
        XCTAssertEqual(rotating.tone, .busy)
        XCTAssertEqual(rotating.progress?.fraction, 0.5)
        XCTAssertEqual(rotating.rotateBlockedReason, SecretsCopy.rotatingReason)
        let stalled = try decode(SecretsStatus.self, status(state: "rotating"))
        XCTAssertTrue(stalled.rotationStalled)
        XCTAssertEqual(stalled.hero.title, "The key rotation stopped before it finished")
        let locked = try decode(SecretsStatus.self, status(state: "locked_missing"))
        XCTAssertTrue(locked.isLocked)
        XCTAssertEqual(locked.tone, .locked)
        let partial = try decode(SecretsStatus.self, status(encrypted: 2, plaintext: 1))
        XCTAssertEqual(partial.hero.title, "2 of 3 secrets encrypted")
    }

    func testUnreadableCopy() throws {
        let s = try decode(SecretsStatus.self, status(unreadable: """
        [{"name": "setting:app_api_key", "kind": "setting", "label": "App API key"},
         {"name": "download_client:1.password", "kind": "download_client", "label": "SABnzbd · password"}]
        """))
        XCTAssertEqual(s.hero.title, "Encrypted with a new key · 3 of 5 secrets readable")
        XCTAssertTrue(SecretsCopy.resetRegenerates(s.unreadable[0]))
        XCTAssertFalse(SecretsCopy.resetRegenerates(s.unreadable[1]))
        XCTAssertEqual(SecretsCopy.kindLabel("download_client"), "Download client")
        XCTAssertEqual(SecretsCopy.resetConsequence(s.unreadable[1]), "Cleared. Enter a new value where it’s used.")
    }

    func testFingerprintAndLists() {
        XCTAssertEqual(SecretsCopy.groupFingerprint("3f9a1c0be27d5a46"), "3f9a·1c0b·e27d·5a46")
        XCTAssertEqual(SecretsCopy.groupFingerprint(nil), "—")
        XCTAssertEqual(SecretsCopy.nameList(["a", "b", "a", "c", "d"]), "a, b, c +1 more")
        let lists = SecretsCopy.lockedLists(SecretsIntegrations(indexers: ["x"], downloadClients: ["SAB"]))
        XCTAssertEqual(lists.paused.first?.small, "SAB")
        XCTAssertEqual(lists.paused[1].small, "1 indexer")
    }

    func testSecretsErrorCopy() {
        let tooNew = APIError.http(status: 403, body: #"{"detail": {"code": "reauth_too_new", "detail": "x"}}"#)
        XCTAssertTrue(SecretsErrorCopy.isTooNew(tooNew))
        XCTAssertTrue(SecretsErrorCopy.message(for: tooNew, keyPath: "/data/k").hasSuffix("copy the key file from the server: /data/k."))
        let unknown = APIError.http(status: 409, body: #"{"detail": {"code": "nope"}}"#)
        XCTAssertEqual(SecretsErrorCopy.message(for: unknown), "That can’t be done in the current state. Refresh and try again.")
        XCTAssertEqual(SecretsErrorCopy.message(for: APIError.http(status: 500, body: "")), SecretsErrorCopy.generic)
        XCTAssertEqual(SecretsErrorCopy.split("One. Two three.").head, "One.")
    }

    func testVisitorIpKeepText() throws {
        let v = try decode(VisitorIpSettings.self, #"{"recording_enabled": true, "retention_days": 90}"#)
        XCTAssertEqual(v.retentionDays, 90)
        XCTAssertEqual(VisitorIpSettings.keepText(on: true, days: 0), "Audit rows keep their address forever.")
    }

    // MARK: Sign-in methods

    func testTrustedProxyChecks() {
        XCTAssertEqual(TrustedProxies.parse("172.18.0.0/16\n 10.0.0.1, ,\n"), ["172.18.0.0/16", "10.0.0.1"])
        XCTAssertNil(TrustedProxies.problem("172.18.0.0/16"))
        XCTAssertNil(TrustedProxies.problem("fd00::/8"))
        XCTAssertEqual(TrustedProxies.problem("10.0.0.1/33"), "10.0.0.1/33: the prefix must be 0–32.")
        XCTAssertEqual(TrustedProxies.problem("proxy"), "proxy isn’t an IP address or CIDR.")
        XCTAssertEqual(TrustedProxies.problem("256.1.1.1"), "256.1.1.1 isn’t an IP address or CIDR.")
    }

    func testPlexResults() throws {
        let test = try decode(SignInPlexTestResult.self,
                              #"{"ok": true, "server_name": "Home", "owner_username": "me", "member_count": 4}"#)
        XCTAssertEqual(test.summary, "Connected to \"Home\" as me · 4 member(s).")
        let prune = try decode(SignInPlexPruneResult.self, #"{"removed": 2, "usernames": ["a", "b"]}"#)
        XCTAssertEqual(prune.summary, "Removed 2 accounts — a, b")
        let connect = try decode(SignInPlexConnectResult.self, #"{"status": "connected", "server_name": "Home"}"#)
        XCTAssertTrue(connect.connected)
    }
}
