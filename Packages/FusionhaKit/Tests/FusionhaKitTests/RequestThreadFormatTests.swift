import XCTest
@testable import FusionhaKit

final class RequestThreadFormatTests: XCTestCase {
    private func person(_ name: String) -> RequestPerson {
        try! APIClient.decoder.decode(RequestPerson.self, from: Data(#"{"id":1,"display_name":"\#(name)"}"#.utf8))
    }

    func testSystemLines() {
        let elmer = person("Elmer")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 1, kind: "SYSTEM", eventType: "created", actor: elmer,
                                                             data: .init(tiers: ["HD_1080P", "UHD_2160P"]))),
                       "Elmer requested HD·1080p and UHD·4K")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 2, kind: "SYSTEM", eventType: "joined", mine: true)), "You joined")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 3, kind: "SYSTEM", eventType: "approved", data: .init(via: "RULE"))),
                       "Auto-approved by a rule")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 4, kind: "SYSTEM", eventType: "approved", actor: elmer, data: .init(via: "ADMIN"))),
                       "Approved by Elmer")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 5, kind: "SYSTEM", eventType: "grabbed", data: .init(tier: "UHD-2160p"))),
                       "Grabbed UHD·4K")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 6, kind: "SYSTEM", eventType: "held", data: .init(rule: "Over 4K budget"))),
                       "Held for review · Over 4K budget")
        XCTAssertEqual(RequestThreadFormat.systemLine(.init(id: 7, kind: "SYSTEM", eventType: "check_started")), "check started")
    }

    func testMessageMeta() {
        let admin = RequestThreadEvent(id: 1, kind: "MESSAGE", eventType: "message", actor: person("Ana"))
        XCTAssertEqual(RequestThreadFormat.messageMeta(admin), "Ana")
        XCTAssertEqual(RequestThreadFormat.messageMeta(admin, joinedView: true), "Ana · to you")
        let broadcast = RequestThreadEvent(id: 2, kind: "MESSAGE", eventType: "broadcast", actor: person("Ana"))
        XCTAssertEqual(RequestThreadFormat.messageMeta(broadcast, joinedView: true), "Ana · to everyone who asked")
        let mine = RequestThreadEvent(id: 3, kind: "MESSAGE", eventType: "message", mine: true)
        XCTAssertEqual(RequestThreadFormat.messageMeta(mine, joinedView: true), "You")
    }

    func testDecodesEvent() throws {
        let json = #"[{"id":9,"kind":"SYSTEM","event_type":"created","actor":null,"actor_kind":"USER","body":null,"data":{"tiers":["HD_1080P"],"extra":{"a":1}},"created_at":"2026-10-15T10:00:00","mine":false}]"#
        let events = try APIClient.decoder.decode([RequestThreadEvent].self, from: Data(json.utf8))
        XCTAssertEqual(events.first?.data?.tiers, ["HD_1080P"])
        XCTAssertEqual(RequestThreadFormat.systemLine(events[0]), "Someone requested HD·1080p")
    }
}
