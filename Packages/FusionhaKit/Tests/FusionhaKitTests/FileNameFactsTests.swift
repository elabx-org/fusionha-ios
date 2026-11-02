import XCTest
@testable import FusionhaKit

/// The Files tab's facts line, read from a filename when the server has none.
final class FileNameFactsTests: XCTestCase {
    func testBracketedArrName() {
        let f = FileNameFacts.parse("64 Zoo Lane (1999)/Season 01/64 Zoo Lane (1999) - S01E01 - The Story of Nelson the Elephant [WEBRip-1080p][AAC 2.0][x265]-TiKos.mkv")
        XCTAssertEqual(f.source, "WEBRip")
        XCTAssertEqual(f.resolution, "1080p")
        XCTAssertEqual(f.quality, "WEBRip 1080p")
        XCTAssertEqual(f.videoCodec, "x265")
        XCTAssertEqual(f.audio, "AAC 2.0")
        XCTAssertEqual(f.releaseGroup, "TiKos")
    }

    func testWebDLAndH264() {
        let f = FileNameFacts.parse("64 Zoo Lane (1999) - S01E02 - The Story of Kevin the Crocodile [WEBDL-720p][AAC 2.0][x264]-AndreMor.mkv")
        XCTAssertEqual(f.quality, "WEB-DL 720p")
        XCTAssertEqual(f.videoCodec, "x264")
        XCTAssertEqual(f.releaseGroup, "AndreMor")
    }

    func testSceneName() {
        let f = FileNameFacts.parse("Show.Name.S02E03.2160p.WEB-DL.DDP5.1.Atmos.H.265-FLUX.mkv")
        XCTAssertEqual(f.quality, "WEB-DL 2160p")
        XCTAssertEqual(f.videoCodec, "h265")
        XCTAssertEqual(f.audio, "DDP 5.1 Atmos")
        XCTAssertEqual(f.releaseGroup, "FLUX")
    }

    func testBlurayTrueHDAndHEVC() {
        let f = FileNameFacts.parse("Film.2019.1080p.BluRay.TrueHD.7.1.HEVC-GRP.mkv")
        XCTAssertEqual(f.quality, "BluRay 1080p")
        XCTAssertEqual(f.videoCodec, "HEVC")
        XCTAssertEqual(f.audio, "TrueHD 7.1")
        XCTAssertEqual(f.releaseGroup, "GRP")
    }

    func testOtherCodecs() {
        XCTAssertEqual(FileNameFacts.parse("a.720p.HDTV.AC3.2.0.h264-X.mkv").audio, "AC3 2.0")
        XCTAssertEqual(FileNameFacts.parse("a.1080p.WEBRip.EAC3.5.1.AV1-X.mkv").audio, "EAC3 5.1")
        XCTAssertEqual(FileNameFacts.parse("a.1080p.WEBRip.EAC3.5.1.AV1-X.mkv").videoCodec, "AV1")
        XCTAssertEqual(FileNameFacts.parse("a.1080p.BluRay.DTS.x264-X.mkv").audio, "DTS")
    }

    func testNoFactsMeansNoGroup() {
        // A hyphenated title is not a release group.
        let f = FileNameFacts.parse("Spider-Man - S01E01 - Pilot-Part.mkv")
        XCTAssertNil(f.releaseGroup)
        XCTAssertNil(f.quality)
        XCTAssertNil(f.audio)
        // Nor is the DL of a trailing WEB-DL.
        XCTAssertNil(FileNameFacts.parse("Show.S01E01.1080p.WEB-DL.mkv").releaseGroup)
    }

    func testTitleNumbersAreNotChannels() {
        let f = FileNameFacts.parse("Show - S01E01 - Room 2.0 [HDTV-720p].mkv")
        XCTAssertNil(f.audio)
        XCTAssertEqual(f.quality, "HDTV 720p")
    }

    func testStem() {
        XCTAssertEqual(FileNameFacts.stem(of: "a/b/c.name.mkv"), "c.name")
        XCTAssertEqual(FileNameFacts.stem(of: "Show.S01E01.1080p"), "Show.S01E01.1080p")
    }

    func testQualityText() {
        XCTAssertEqual(FileNameFacts.qualityText("WEBRIP_1080P"), "WEBRip 1080p")
        XCTAssertEqual(FileNameFacts.qualityText("WEBDL_720P"), "WEB-DL 720p")
        XCTAssertEqual(FileNameFacts.qualityText("REMUX_2160P"), "Remux 2160p")
        XCTAssertEqual(FileNameFacts.qualityText("DVD"), "DVD")
        XCTAssertNil(FileNameFacts.qualityText("UNKNOWN"))
        XCTAssertNil(FileNameFacts.qualityText(nil))
    }

    func testBelowTier() {
        XCTAssertTrue(FileNameFacts.isBelow(resolution: "720p", tier: .hd))
        XCTAssertFalse(FileNameFacts.isBelow(resolution: "1080p", tier: .hd))
        XCTAssertTrue(FileNameFacts.isBelow(resolution: "1080p", tier: .uhd))
        XCTAssertFalse(FileNameFacts.isBelow(resolution: nil, tier: .uhd))
    }
}
