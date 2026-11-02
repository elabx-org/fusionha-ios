import XCTest
@testable import FusionhaKit

/// `MediaFileRead.video_codec` / `audio_codec` / `audio_channels` (fusionha
/// 0.4.236): the Files tab's facts line prefers them and reads the filename
/// only when they are null.
final class FileProbeFactsTests: XCTestCase {
    private let path = "Show/Season 01/Show - S01E01 [WEBRip-1080p][AAC 2.0][x265]-TiKos.mkv"

    private func file(video: String? = nil, audio: String? = nil, channels: String? = nil) throws -> MovieFile {
        func q(_ s: String?) -> String { s.map { "\"\($0)\"" } ?? "null" }
        let json = """
        {"id": 1, "relative_path": "\(path)", "size": 1000, "quality": "WEBRip-1080p", "media_info": {},
         "release_group": "TiKos", "cf_score": 0, "custom_formats": [],
         "video_codec": \(q(video)), "audio_codec": \(q(audio)), "audio_channels": \(q(channels))}
        """
        return try APIClient.decoder.decode(MovieFile.self, from: Data(json.utf8))
    }

    func testDecodesTheProbeFields() throws {
        let f = try file(video: "h265", audio: "EAC3 Atmos", channels: "5.1")
        XCTAssertEqual(f.videoCodec, "h265")
        XCTAssertEqual(f.audioCodec, "EAC3 Atmos")
        XCTAssertEqual(f.audioChannels, "5.1")
        XCTAssertEqual(f.probedVideo, "h265")
        XCTAssertEqual(f.probedAudio, "EAC3 Atmos 5.1")
    }

    func testAnOlderServerOmitsThem() throws {
        let json = #"{"id": 1, "relative_path": "a.mkv", "size": 1}"#
        let f = try APIClient.decoder.decode(MovieFile.self, from: Data(json.utf8))
        XCTAssertNil(f.videoCodec)
        XCTAssertNil(f.probedAudio)
    }

    func testProbeFieldsWinOverTheName() throws {
        let f = try file(video: "h265", audio: "DTS-HD MA", channels: "7.1")
        let media = FileNameFacts.media(for: f, name: FileNameFacts.parse(path))
        XCTAssertEqual(media.video, "h265")
        XCTAssertEqual(media.audio, "DTS-HD MA 7.1")
    }

    func testNullFieldsFallBackToTheName() throws {
        let f = try file()
        XCTAssertNil(f.probedVideo)
        XCTAssertNil(f.probedAudio)
        let media = FileNameFacts.media(for: f, name: FileNameFacts.parse(path))
        XCTAssertEqual(media.video, "x265")
        XCTAssertEqual(media.audio, "AAC 2.0")
    }

    func testEachFactFallsBackOnItsOwn() throws {
        let f = try file(video: "AV1")
        let media = FileNameFacts.media(for: f, name: FileNameFacts.parse(path))
        XCTAssertEqual(media.video, "AV1")
        XCTAssertEqual(media.audio, "AAC 2.0")
    }

    func testChannelsWithoutACodecAreDropped() throws {
        XCTAssertNil(try file(channels: "2.0").probedAudio)
        XCTAssertEqual(try file(audio: "AAC").probedAudio, "AAC")
    }

    func testTheDeviceProbeSitsBetween() throws {
        let media = FileNameFacts.media(for: try file(), probeVideo: "HEVC", probeAudio: nil, name: FileNameFacts.parse(path))
        XCTAssertEqual(media.video, "HEVC")
        XCTAssertEqual(media.audio, "AAC 2.0")
    }
}
