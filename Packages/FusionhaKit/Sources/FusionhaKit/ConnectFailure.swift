import Foundation

/// Why the server step couldn't reach fusionha, in words that say what to try.
public enum ConnectFailure: Equatable, Sendable {
    case invalid
    case unreachable
    case timedOut
    case tls
    case notFusionha
    /// iOS blocked a LAN address: Local Network permission is off.
    case localNetworkDenied
    case server(Int)

    public static func classify(_ error: Error, host: URL? = nil) -> ConnectFailure {
        if case APIError.invalidServerURL = error { return .invalid }
        if case APIError.http(let status, _) = error {
            // A 404 on /health is something else answering on that address.
            return status == 404 || status == 405 ? .notFusionha : .server(status)
        }
        if error is DecodingError { return .notFusionha }
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return .unreachable }
        switch URLError.Code(rawValue: ns.code) {
        case .timedOut:
            return .timedOut
        case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected, .clientCertificateRequired,
             .secureConnectionFailed, .appTransportSecurityRequiresSecureConnection:
            return .tls
        case .notConnectedToInternet:
            // On a LAN address this is iOS's Local Network refusal, not the Wi-Fi.
            if let host, ServerAddress.isLocal(host) { return .localNetworkDenied }
            return .unreachable
        case .badServerResponse, .cannotParseResponse, .cannotDecodeContentData, .cannotDecodeRawData,
             .zeroByteResource, .httpTooManyRedirects, .redirectToNonExistentLocation:
            return .notFusionha
        default:
            return .unreachable
        }
    }

    /// When several addresses were tried, the one worth telling: anything that
    /// answered beats "no answer".
    public static func mostTelling(_ failures: [ConnectFailure]) -> ConnectFailure {
        let rank: (ConnectFailure) -> Int = {
            switch $0 {
            case .localNetworkDenied: return 6
            case .tls: return 5
            case .notFusionha: return 4
            case .server: return 3
            case .timedOut: return 2
            case .unreachable: return 1
            case .invalid: return 0
            }
        }
        return failures.max { rank($0) < rank($1) } ?? .unreachable
    }

    public var message: String {
        switch self {
        case .invalid:
            return "That doesn't look like an address. Try the one you open the web app at."
        case .unreachable:
            return "Nothing answered there. Check the address, and that this phone is on the same network or VPN."
        case .timedOut:
            return "The server took too long to answer. Is it running, and reachable from this phone?"
        case .tls:
            return "The secure connection failed. Check the certificate, or try http:// for a home address."
        case .notFusionha:
            return "Something answered, but it isn't fusionha. Check the port, or the path behind your proxy."
        case .localNetworkDenied:
            return "iOS blocked the home network. Turn on Local Network for fusionha in Settings."
        case .server(let status):
            return "fusionha answered with an error (HTTP \(status)). Try again in a moment."
        }
    }
}
