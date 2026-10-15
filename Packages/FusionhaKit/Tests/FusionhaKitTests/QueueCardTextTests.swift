import XCTest
@testable import FusionhaKit

final class QueueCardTextTests: XCTestCase {
    private func item(_ extra: String) throws -> QueueItem {
        let json = """
        {"id":7,"title":"The Office (US)","episode_label":"S06E04","release_title":"The.Office.S06E04.1080p.BluRay.DDP.5.1.x265-edge2020",
         "status":"held","size":1800000000,"sizeleft":0,"progress":100,"stalled":false,"media_item_id":3,"edition_id":9,
         "tier":"HD-1080p","protocol":"USENET","download_client":"SABnzbd (decypharr)","indexer":"Digitalcarnage (Prowlarr)",
         "age_seconds":79200\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    func testMetaWords() throws {
        let i = try item("")
        XCTAssertEqual(QueueCardText.grabbedAgo(i.ageSeconds), "grabbed 22h ago")
        XCTAssertEqual(QueueCardText.grabbedAgo(30), "grabbed just now")
        XCTAssertEqual(QueueCardText.grabbedAgo(3 * 86400), "grabbed 3d ago")
        XCTAssertEqual(QueueCardText.subtitle(i), "S06E04")
        XCTAssertEqual(QueueCardText.versionLabel(i), "HD")
        let split = QueueCardText.splitIndexer("Digitalcarnage (Prowlarr)")
        XCTAssertEqual(split.name, "Digitalcarnage")
        XCTAssertEqual(split.via, "Synced from Prowlarr")
        XCTAssertNil(QueueCardText.splitIndexer("Miatrix").via)
    }

    func testHeldReasonAndRail() throws {
        let i = try item(#","held_reason":"would orphan other episodes of a multi-episode file""#)
        XCTAssertEqual(QueueCardText.heldReason(i).lead, "Would orphan other episodes of a multi-episode file")
        let rail = QueueRail.held(i)
        XCTAssertEqual(rail.nodes.map(\.label), ["Grabbed", "Linked by decypharr"])
        XCTAssertEqual(rail.importNode.label, "Import held")
    }

    func testMislabelledHoldReadsAsSmallerWithGuard() throws {
        let i = try item(#","held_detail":{"kind":"mislabeled","mislabeled":true,"claimed_quality":"WEBDL_2160P","probed_quality":"WEBDL_1080P","claimed_resolution":2160,"probed_resolution":{"w":2560,"h":1440},"current_group":"FUZEER"}"#)
        let reason = QueueCardText.heldReason(i)
        XCTAssertEqual(reason.lead, "Smaller than its name says")
        XCTAssertEqual(reason.guard, "would replace your HD FUZEER copy")
    }

    func testFactsFromTheName() throws {
        let i = try item(#","parsed":{"quality":"BLURAY_1080P","video_codec":"HEVC","audio_label":"DDP 5.1","release_group":"edge2020"}"#)
        let facts = CapabilityChips.queueFacts(i)
        XCTAssertEqual(facts.map(\.key), ["quality", "video", "audio", "group"])
        XCTAssertEqual(facts.map(\.model.text), ["Bluray-1080p", "H.265", "DDP 5.1", "edge2020"])
        XCTAssertTrue(facts.allSatisfy { $0.model.base == .named })
    }

    func testProbedAndDisprovedQuality() throws {
        let i = try item(#","parsed":{"quality":"WEBDL_2160P","video_codec":"HEVC"},"probe":{"state":"ok","video_codec":"hevc","width":2560,"height":1440,"hdr_format":"dv_hdr10"},"held_detail":{"mislabeled":true,"claimed_quality":"WEBDL_2160P","probed_quality":"WEBDL_1080P"}"#)
        let facts = CapabilityChips.queueFacts(i)
        XCTAssertEqual(facts[0].model.text, "WEBDL-2160p→WEBDL-1080p")
        XCTAssertTrue(facts[0].model.hasDiff)
        XCTAssertEqual(facts[1].model.text, "2560×1440 · DV · HDR10 · HEVC")
        XCTAssertEqual(facts[1].model.base, .probed)
    }
}

final class QueueRailTests: XCTestCase {
    private func stages(_ current: String, failed: Bool = false) throws -> QueueStages {
        let json = """
        {"mode":"phase","route":"usenet","current":"\(current)","completed":3,"total":6,"failed":\(failed),
         "linking_done":4,"linking_total":12,
         "steps":[{"key":"queued","runs":true},{"key":"parsing","runs":true},{"key":"processed","runs":true},
                  {"key":"linking","runs":true},{"key":"caching","runs":false},{"key":"validating","runs":true},{"key":"complete","runs":true}]}
        """
        return try APIClient.decoder.decode(QueueStages.self, from: Data(json.utf8))
    }

    func testPhaseNodes() throws {
        let nodes = QueueRail.phaseNodes(try stages("linking"))
        XCTAssertEqual(nodes.map(\.state), [.done, .done, .done, .active, .off, .todo, .todo])
        XCTAssertEqual(nodes[3].count, "4/12")
    }

    func testFailedHoldsTheFurthestStage() throws {
        let nodes = QueueRail.phaseNodes(try stages("parsing", failed: true), failed: true)
        XCTAssertEqual(nodes[1].state, .fail)
        XCTAssertEqual(nodes[1].label, "Failed at parsing")
        XCTAssertEqual(QueueRail.ring(try stages("parsing"))?.total, 6)
    }
}
