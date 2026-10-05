import XCTest
@testable import FusionhaKit

final class AddFlowTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = .sortedKeys
        return e
    }

    // MARK: Monitor preview parity (the backend's shared fixture)

    private struct ParityFixture: Decodable {
        struct Season: Decodable {
            let season_number: Int
            let offsets: [Int?]
        }
        struct Case: Decodable {
            let name: String
            let seasons: [Season]
            let expected: [String: [String: [Int]]]
        }
        let recent_days: Int
        let cases: [Case]
    }

    func testMonitorPreviewMatchesTheBackendFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "monitor_parity", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(ParityFixture.self, from: Data(contentsOf: url))
        for c in fixture.cases {
            let seasons = c.seasons.map { s -> SeasonCounts in
                let aired = s.offsets.compactMap { $0 }.filter { $0 < 0 }
                return SeasonCounts(seasonNumber: s.season_number, episodeCount: s.offsets.count,
                                    airedCount: aired.count, recentCount: aired.filter { $0 >= -fixture.recent_days }.count)
            }
            for (mode, expected) in c.expected {
                let preview = MonitorPreview.compute(seasons, mode: mode)
                var got: [String: [Int]] = [:]
                for s in preview.perSeason where !s.lit.isEmpty {
                    got[String(s.seasonNumber)] = s.lit.map { $0 + 1 }
                }
                XCTAssertEqual(got, expected, "\(c.name) · \(mode)")
            }
        }
    }

    func testDateModesAreInexactWithoutAirData() {
        let seasons = [SeasonCounts(seasonNumber: 1, episodeCount: 8, airedCount: nil, recentCount: nil)]
        for mode in ["future", "existing", "recent"] {
            let p = MonitorPreview.compute(seasons, mode: mode)
            XCTAssertFalse(p.exact)
            XCTAssertEqual(p.count, 0)
        }
        XCTAssertTrue(MonitorPreview.compute(seasons, mode: "all").exact)
        XCTAssertEqual(MonitorPreview.compute(seasons, mode: "all").count, 8)
    }

    // MARK: Season slider

    func testCustomBuildsOnAllAndPayloadSendsNulls() throws {
        let seasons = [SeasonCounts(seasonNumber: 1, episodeCount: 10, airedCount: 10, recentCount: 0),
                       SeasonCounts(seasonNumber: 2, episodeCount: 8, airedCount: 2, recentCount: 2)]
        // Pilot → the whole S1 from E1, S2 none.
        let pilot = SeasonSlider.materialise(seasons, mode: "pilot")
        XCTAssertEqual(pilot[1], .some(1))
        XCTAssertEqual(pilot[2], .some(nil))
        // Future → S1 none, S2 from E3.
        let future = SeasonSlider.materialise(seasons, mode: "future")
        XCTAssertEqual(future[1], .some(nil))
        XCTAssertEqual(future[2], .some(3))
        let applied = SeasonSlider.apply(seasons, MonitorPreview.compute(seasons, mode: "all"), [2: 5])
        XCTAssertEqual(applied.count, 14)
        let body = try XCTUnwrap(SeasonSlider.payload([2: 5, 1: nil]))
        let json = String(decoding: try encoder.encode(body), as: UTF8.self)
        XCTAssertEqual(json, #"[{"from_episode":null,"season_number":1},{"from_episode":5,"season_number":2}]"#)
        XCTAssertNil(SeasonSlider.payload([:]))
        XCTAssertEqual(SeasonSlider.bubble(from: 0, episodeCount: 8), "Whole season · 8")
        XCTAssertEqual(SeasonSlider.bubble(from: 3, episodeCount: 8), "From E4 · 5 episodes")
        XCTAssertEqual(SeasonSlider.bubble(from: 8, episodeCount: 8), "None")
        XCTAssertEqual(SeasonSlider.start(from0: 8, episodeCount: 8), nil)
        XCTAssertEqual(SeasonSlider.toggled(litCount: 8, episodeCount: 8), nil)
        XCTAssertEqual(SeasonSlider.toggled(litCount: 3, episodeCount: 8), 1)
    }

    // MARK: Sentences

    func testSummarySentence() {
        let series = AddSentence.summary(isSeries: true, versions: [(.hd, nil), (.uhd, nil)], searchNow: true,
                                         monitor: .init(mode: "all", count: 208, exact: true), monitorUhd: nil, stop: nil)
        XCTAssertEqual(series.map(\.text).joined(), "Adds HD·1080p + UHD·4K · monitors 208 episodes · searches now")
        let movie = AddSentence.summary(isSeries: false, versions: [(.hd, "Director's Cut")], searchNow: false,
                                        monitor: nil, monitorUhd: nil, stop: ("In cinemas", "18 Dec 2026"))
        XCTAssertEqual(movie.map(\.text).joined(), "Adds HD·1080p · Director's Cut · grabs from in cinemas (18 Dec 2026)")
        XCTAssertEqual(AddSentence.summary(isSeries: false, versions: [], searchNow: true, monitor: nil, monitorUhd: nil,
                                           stop: nil).map(\.text).joined(), "Turn on at least one version.")
    }

    // MARK: Timeline

    private var today: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 29; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func testTimelineStopsAndToday() {
        let t = ReleaseTimelineModel.build(TimelineDates(inCinemas: "2026-12-18", estimateDate: "2027-03-18",
                                                         estimateIsEstimated: true), today: today)
        XCTAssertEqual(t.stops.map(\.pos), [12, 50, 88])
        XCTAssertEqual(t.stops[1].dateText, "18 Dec 2026")
        XCTAssertEqual(t.stops[2].dateText, "est. Mar 2027")
        XCTAssertEqual(t.stops[2].dateBody, "Mar 2027")
        XCTAssertTrue(t.stops[2].estimated)
        // 80 days until cinemas: 12 + 38 * (1 - 80/180).
        XCTAssertEqual(t.today ?? 0, 12 + 38 * (1 - 80.0 / 180), accuracy: 0.001)
        XCTAssertEqual(t.stops[1].when, "in 3 months")
        XCTAssertEqual(t.stops[2].when, "in ~6 months")
        XCTAssertNil(ReleaseTimelineModel.build(TimelineDates(), today: today).today)
        XCTAssertEqual(ReleaseTimelineModel.build(TimelineDates(), today: today).stops[1].dateText, "date unknown")
        XCTAssertEqual(ReleaseTimelineModel.relativeUntil(1), "tomorrow")
        XCTAssertEqual(ReleaseTimelineModel.relativeUntil(-3, estimated: true), "any day now")
        XCTAssertEqual(ReleaseTimelineModel.formatStopDate("2027-03-02", estimated: true), "est. Mar 2027")
    }

    func testTitleYear() {
        XCTAssertEqual(TitleYear.titleWithYear("Monster (2022)", 2022), "Monster (2022)")
        XCTAssertEqual(TitleYear.titleWithYear("Dune", 2021), "Dune (2021)")
        XCTAssertEqual(TitleYear.display("Monster (2022)", nil).title, "Monster")
        XCTAssertEqual(TitleYear.display("Monster (2022)", nil).year, 2022)
    }

    // MARK: Wire shapes

    func testPreviewDecodesTvdbOnlyAndAddV2Fields() throws {
        let preview = try decoder.decode(AddPreview.self, from: Data(#"""
            {"tmdb_id": null, "title": "Monster (2022)", "year": 2022, "kind": "series", "is_anime": false,
             "in_library": false, "tvdb_id": 81189, "imdb_id": "tt1", "seasons": [
               {"season_number": 1, "episode_count": 10, "aired_count": 4, "recent_count": 2},
               {"season_number": 2, "episode_count": 8}],
             "release_estimate": {"date": "2027-03-18", "stage": "digital", "estimated": true},
             "next_air_date": "2026-10-10"}
            """#.utf8))
        XCTAssertNil(preview.tmdbId)
        XCTAssertEqual(preview.seasons?.first?.airedCount, 4)
        XCTAssertNil(preview.seasons?.last?.airedCount)
        XCTAssertEqual(preview.timelineDates.estimateDate, "2027-03-18")
        let last = try decoder.decode(LastAdded?.self, from: Data("null".utf8))
        XCTAssertNil(last)
    }

    func testAddBodySpeaksVersions() throws {
        let body = AddTitleBody(title: "Dune", kind: .movie, year: 2021, tmdbId: 438631, tvdbId: nil, isAnime: false,
                                versions: [AddVersionBody(tier: .hd, edition: nil, rootFolderId: 1, qualityProfileId: 2,
                                                          monitor: nil, folderName: nil)],
                                searchNow: true, monitor: "all", minimumAvailability: "released", seriesType: nil,
                                metadataProvider: nil, seasonMonitorFrom: nil)
        let json = String(decoding: try encoder.encode(body), as: UTF8.self)
        XCTAssertTrue(json.contains(#""versions":[{"monitored":true,"quality_profile_id":2,"root_folder_id":1,"tier":"HD-1080p"}]"#), json)
        XCTAssertFalse(json.contains("editions"))
        XCTAssertFalse(json.contains("season_monitor_from"))
    }
}
