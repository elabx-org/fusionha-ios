import XCTest
@testable import FusionhaKit

/// The season page's file facts chips: what the season shares is said once,
/// a row keeps its size and only the facts that differ.
final class SeasonFileFactsTests: XCTestCase {
    private func file(_ id: Int, quality: String? = "WEBDL_1080P", group: String? = "Kitsune",
                      audio: String? = "EAC3", channels: String? = "5.1", size: Double? = 2_576_980_378) throws -> MovieFile {
        func q(_ s: String?) -> String { s.map { "\"\($0)\"" } ?? "null" }
        let json = """
        {"id": \(id), "relative_path": "Show/Season 01/e\(id).mkv", "size": \(size.map { String($0) } ?? "null"),
         "quality": \(q(quality)), "release_group": \(q(group)),
         "video_codec": "h264", "audio_codec": \(q(audio)), "audio_channels": \(q(channels))}
        """
        return try APIClient.decoder.decode(MovieFile.self, from: Data(json.utf8))
    }

    func testChipTextsComeFromTheServerFields() throws {
        let f = try file(1)
        XCTAssertEqual(SeasonFileFacts.value(.source, of: f), "WEB-DL 1080p")
        XCTAssertEqual(SeasonFileFacts.value(.audio, of: f), "EAC3 5.1")
        XCTAssertEqual(SeasonFileFacts.value(.group, of: f), "Kitsune")
        XCTAssertEqual(SeasonFileFacts.value(.source, of: try file(2, quality: "WEBRIP_1080P")), "WEBRip 1080p")
    }

    func testUnanalysedAudioHasNoChip() throws {
        let f = try file(1, audio: nil, channels: nil)
        XCTAssertNil(SeasonFileFacts.value(.audio, of: f))
        XCTAssertNil(SeasonFileFacts.value(.group, of: try file(2, group: "  ")))
        XCTAssertNil(SeasonFileFacts.value(.source, of: try file(3, quality: "UNKNOWN")))
    }

    func testAllAlikeShareEverythingAndRowsKeepOnlyTheSize() throws {
        let files = try (1...3).map { try file($0) }
        let facts = SeasonFileFacts(files: files)
        XCTAssertEqual(facts.shared.map(\.text), ["WEB-DL 1080p", "EAC3 5.1", "Kitsune"])
        XCTAssertEqual(facts.shared.map(\.kind), [.source, .audio, .group])
        let line = facts.line(for: files[0])
        XCTAssertTrue(line.chips.isEmpty)
        XCTAssertEqual(line.size, "2.4 GB")
        XCTAssertEqual(facts.fileCount, 3)
        XCTAssertEqual(facts.totalSize, "7.2 GB")
    }

    func testTheOddOneOutShowsItsDifferencesMarked() throws {
        let odd = try file(9, quality: "WEBRIP_1080P", group: "NTb")
        let files = try [file(1), file(2), file(3), odd]
        let facts = SeasonFileFacts(files: files)
        XCTAssertEqual(facts.shared.map(\.text), ["WEB-DL 1080p", "EAC3 5.1", "Kitsune"])
        let line = facts.line(for: odd)
        XCTAssertEqual(line.chips.map(\.text), ["WEBRip 1080p", "NTb"])
        XCTAssertTrue(line.chips.allSatisfy(\.differs))
        XCTAssertTrue(facts.line(for: files[0]).chips.isEmpty)
    }

    func testNothingSharedShowsEveryChipUnmarked() throws {
        let files = try [file(1, quality: "WEBDL_1080P", group: "A", audio: "AAC", channels: "2.0"),
                         file(2, quality: "BLURAY_1080P", group: "B", audio: "DTS", channels: "5.1")]
        let facts = SeasonFileFacts(files: files)
        XCTAssertTrue(facts.shared.isEmpty)
        let line = facts.line(for: files[1])
        XCTAssertEqual(line.chips.map(\.text), ["BluRay 1080p", "DTS 5.1", "B"])
        XCTAssertFalse(line.chips.contains(where: \.differs))
    }

    func testOneFileSharesNothing() throws {
        let only = try file(1)
        let facts = SeasonFileFacts(files: [only])
        XCTAssertTrue(facts.shared.isEmpty)
        XCTAssertEqual(facts.line(for: only).chips.count, 3)
    }

    func testSharedNeedsAStrictMajorityOfKnownValues() {
        XCTAssertEqual(SeasonFileFacts.sharedValue(["a", "a", "b"]), "a")
        XCTAssertNil(SeasonFileFacts.sharedValue(["a", "a", "b", "b"]))
        XCTAssertEqual(SeasonFileFacts.sharedValue(["a", nil, "a", nil]), "a")
        XCTAssertNil(SeasonFileFacts.sharedValue(["a", nil, nil]))
        XCTAssertNil(SeasonFileFacts.sharedValue([]))
    }

    func testAFileMissingASharedFactShowsNoChipForIt() throws {
        let unread = try file(4, audio: nil, channels: nil)
        let facts = SeasonFileFacts(files: try [file(1), file(2), unread])
        XCTAssertEqual(facts.shared.map(\.kind), [.source, .audio, .group])
        XCTAssertTrue(facts.line(for: unread).chips.isEmpty)
    }

    func testNoSizeMeansNoSizeText() throws {
        let f = try file(1, size: nil)
        XCTAssertNil(SeasonFileFacts(files: [f]).line(for: f).size)
        XCTAssertNil(SeasonFileFacts(files: [f]).totalSize)
    }

    func testSpeechIsOneSentence() {
        let chips = [FileFactChip(kind: .source, text: "WEBRip 1080p", differs: true), FileFactChip(kind: .group, text: "NTb")]
        XCTAssertEqual(FileFactsSpeech.line(chips, size: "3.6 GB"),
                       "3.6 GB, quality WEBRip 1080p, differs from the season, group NTb")
    }

    func testPerVersionSkipsVersionsWithoutFiles() throws {
        let json = """
        {"season_number": 1, "episodes": [
          {"id": 11, "episode_number": 1, "files": [{"version_id": 1, "tier": "HD-1080p",
            "file": {"id": 101, "size": 100, "quality": "WEBDL_1080P"}}]},
          {"id": 12, "episode_number": 2, "files": [{"version_id": 1, "tier": "HD-1080p",
            "file": {"id": 102, "size": 200, "quality": "WEBDL_1080P"}}]}]}
        """
        let season = try APIClient.decoder.decode(Season.self, from: Data(json.utf8))
        let editions = try ["{\"id\": 1, \"tier\": \"HD-1080p\", \"monitored\": true}",
                            "{\"id\": 2, \"tier\": \"UHD-2160p\", \"monitored\": true}"].map {
            try APIClient.decoder.decode(DetailEdition.self, from: Data($0.utf8))
        }
        let per = SeasonFileFacts.perVersion(season, editions: editions)
        XCTAssertEqual(per.map(\.editionId), [1])
        XCTAssertEqual(per.first?.facts.fileCount, 2)
        XCTAssertEqual(per.first?.facts.shared.map(\.text), ["WEB-DL 1080p"])
    }
}
