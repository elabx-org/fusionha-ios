import Foundation
import FusionhaKit

/// What the server step learned about an address before anyone signs in:
/// `/health` (its version) and `/api/v1/setup-status` (the login look and the
/// sign-in methods). Both are unauthenticated (fusionha #64).
struct ServerProbe {
    let url: URL
    let status: SetupStatus
    let version: String

    var host: String { ServerAddress.label(url) }
}

struct ServerProbeError: Error {
    let failure: ConnectFailure
    let tried: URL?
}

extension AppModel {
    /// Step 1: tries each address `ServerAddress.candidates` offers for the
    /// input (https before http for a domain; the default port for a LAN host),
    /// with a short timeout, and keeps the first that answers as fusionha.
    func probe(_ input: String) async throws -> ServerProbe {
        let candidates = ServerAddress.candidates(input)
        guard !candidates.isEmpty else { throw ServerProbeError(failure: .invalid, tried: nil) }
        var failures: [ConnectFailure] = []
        for url in candidates {
            try Task.checkCancellation()
            let client = APIClient(baseURL: url, token: nil, session: Self.probeSession)
            do {
                let health = try await client.health()
                let status = try await client.setupStatus()
                return ServerProbe(url: url, status: status, version: health.version)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let failure = ConnectFailure.classify(error, host: url)
                failures.append(failure)
                // iOS refused the LAN outright; another port won't help.
                if failure == .localNetworkDenied { break }
            }
        }
        throw ServerProbeError(failure: ConnectFailure.mostTelling(failures), tried: candidates.first)
    }

    /// No cookies, no cache, and a quick give-up: this only asks "is fusionha here?".
    private static let probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
}
