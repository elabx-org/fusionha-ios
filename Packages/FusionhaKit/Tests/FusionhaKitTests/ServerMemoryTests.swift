import XCTest
@testable import FusionhaKit

/// fusionha #65: a fresh install has no default server, no pre-filled address
/// and nothing to auto-connect to.
final class ServerMemoryTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suite = "ServerMemoryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testFreshInstallHasEmptyAddressAndNoStoredServer() {
        let memory = ServerMemory(defaults: defaults)
        XCTAssertEqual(memory.initialAddress, "")
        XCTAssertTrue(memory.recents.isEmpty)
        XCTAssertNil(memory.storedServerURL)
        XCTAssertFalse(memory.localNetworkExplained)
        XCTAssertNil(defaults.string(forKey: ServerMemory.legacyAddressKey))
    }

    func testAddressStaysEmptyEvenWithRecents() {
        let memory = ServerMemory(defaults: defaults)
        memory.remember(RememberedServer(url: URL(string: "https://fusionha.example.com")!))
        XCTAssertEqual(memory.initialAddress, "")
        XCTAssertEqual(memory.recents.map(\.label), ["fusionha.example.com"])
    }

    func testLegacyPrefillIsDroppedNotMigrated() {
        defaults.set("192.168.1.10:8000", forKey: ServerMemory.legacyAddressKey)
        let memory = ServerMemory(defaults: defaults)
        memory.dropLegacyAddress()
        XCTAssertNil(defaults.string(forKey: ServerMemory.legacyAddressKey))
        XCTAssertTrue(memory.recents.isEmpty)
    }

    func testRecentsAreNewestFirstDedupedAndCapped() {
        let memory = ServerMemory(defaults: defaults)
        let base = Date(timeIntervalSince1970: 1_000)
        for (i, host) in ["a.example", "b.example", "c.example", "d.example"].enumerated() {
            memory.remember(RememberedServer(url: URL(string: "https://\(host)")!, lastConnected: base + Double(i)))
        }
        memory.remember(RememberedServer(url: URL(string: "https://c.example")!, loginLayout: "living",
                                         lastConnected: base + 10))
        XCTAssertEqual(memory.recents.map(\.label), ["c.example", "d.example", "b.example"])
        XCTAssertEqual(memory.remembered(URL(string: "https://c.example")!)?.loginLayout, "living")
        memory.forget(URL(string: "https://c.example")!)
        XCTAssertEqual(memory.recents.count, 2)
    }
}

final class ServerAddressTests: XCTestCase {
    func testCleanDropsPastedWebAppPathsAndQuotes() {
        XCTAssertEqual(ServerAddress.clean("  https://fusionha.example.com/library?tab=all \n"), "https://fusionha.example.com")
        XCTAssertEqual(ServerAddress.clean("\"192.168.1.10:8000/discover\""), "192.168.1.10:8000")
        XCTAssertEqual(ServerAddress.clean("https://home.example/fusionha/"), "https://home.example/fusionha")
    }

    func testCandidatesForPublicDomainTryHttpsFirst() {
        XCTAssertEqual(ServerAddress.candidates("fusionha.example.com").map(\.absoluteString),
                       ["https://fusionha.example.com", "http://fusionha.example.com"])
    }

    func testCandidatesForLanHostAddDefaultPort() {
        XCTAssertEqual(ServerAddress.candidates("192.168.1.10").map(\.absoluteString),
                       ["http://192.168.1.10", "http://192.168.1.10:8000"])
        XCTAssertEqual(ServerAddress.candidates("nas:8989").map(\.absoluteString), ["http://nas:8989"])
    }

    func testExplicitSchemeIsUsedAsTyped() {
        XCTAssertEqual(ServerAddress.candidates("http://fusionha.example.com:8000").map(\.absoluteString),
                       ["http://fusionha.example.com:8000"])
        XCTAssertTrue(ServerAddress.candidates("   ").isEmpty)
    }

    func testLocalHosts() {
        for host in ["192.168.0.5", "10.0.0.2", "172.20.1.1", "nas", "tower.local", "100.100.1.1", "fd00::1"] {
            XCTAssertTrue(ServerAddress.isLocal(host: host), host)
        }
        for host in ["fusionha.example.com", "8.8.8.8", "172.32.0.1"] {
            XCTAssertFalse(ServerAddress.isLocal(host: host), host)
        }
    }

    func testPasteHeuristic() {
        XCTAssertTrue(ServerAddress.looksPasted(old: "", new: "https://fusionha.example.com"))
        XCTAssertFalse(ServerAddress.looksPasted(old: "fusio", new: "fusion"))
    }
}

final class ConnectFailureTests: XCTestCase {
    private let lan = URL(string: "http://192.168.1.10")!
    private let web = URL(string: "https://fusionha.example.com")!

    func testClassifiesTheUsualSuspects() {
        XCTAssertEqual(ConnectFailure.classify(URLError(.timedOut), host: web), .timedOut)
        XCTAssertEqual(ConnectFailure.classify(URLError(.serverCertificateUntrusted), host: web), .tls)
        XCTAssertEqual(ConnectFailure.classify(URLError(.cannotFindHost), host: web), .unreachable)
        XCTAssertEqual(ConnectFailure.classify(URLError(.notConnectedToInternet), host: lan), .localNetworkDenied)
        XCTAssertEqual(ConnectFailure.classify(URLError(.notConnectedToInternet), host: web), .unreachable)
        XCTAssertEqual(ConnectFailure.classify(APIError.http(status: 404, body: ""), host: web), .notFusionha)
        XCTAssertEqual(ConnectFailure.classify(APIError.http(status: 502, body: ""), host: web), .server(502))
        XCTAssertEqual(ConnectFailure.classify(APIError.invalidServerURL), .invalid)
        let notJSON = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "html"))
        XCTAssertEqual(ConnectFailure.classify(notJSON, host: web), .notFusionha)
    }

    func testMostTellingPrefersAnAnswerOverSilence() {
        XCTAssertEqual(ConnectFailure.mostTelling([.unreachable, .notFusionha]), .notFusionha)
        XCTAssertEqual(ConnectFailure.mostTelling([.timedOut, .unreachable]), .timedOut)
        XCTAssertEqual(ConnectFailure.mostTelling([]), .unreachable)
    }
}
