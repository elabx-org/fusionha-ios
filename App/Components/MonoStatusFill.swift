import SwiftUI
import FusionhaKit

/// Monochrome's rail states: with no hue to lean on, each state is a shade
/// and a pattern (fusionha 0.4.221 `statusVars` on the CoverageRail fill).
/// A warning (dead links, not found) reads as stuck.
enum MonoStatus {
    case done, downloading, wanted, upcoming, upgrading, warning

    init(_ state: RailState, attention: Bool) {
        if attention { self = .warning; return }
        switch state {
        case .owned: self = .done
        case .downloading: self = .downloading
        case .partial, .wanted: self = .wanted
        case .upcoming: self = .upcoming
        case .upgrading: self = .upgrading
        }
    }

    var token: MonoToken {
        switch self {
        case .done: return .done
        case .downloading: return .grab
        case .wanted: return .miss
        case .upcoming: return .unaired
        case .upgrading: return .edition
        case .warning: return .stuck
        }
    }
}

/// A rail fill in Monochrome: the status' solid shade with its pattern over it.
struct MonoRailFill: View {
    let status: MonoStatus

    var body: some View {
        StatusSwatch(token: status.token, shape: Capsule())
    }
}
