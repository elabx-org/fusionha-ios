import Foundation
import FusionhaKit

/// What the signed-in account may do, and the shell's badges and settings
/// read through to `ShellState` (ShellState.swift).
extension AppModel {
    var attentionCount: Int { shell.attentionCount }
    var pendingRequests: Int { shell.pendingRequests }
    /// The Requests badge (Proposal 2): pending requests plus issues needing
    /// action, each counted only for someone who can act on it.
    var requestsBadge: Int {
        (canApproveRequests ? shell.pendingRequests : 0) + (canManageIssues ? shell.issuesNeedingAction : 0)
    }
    var canManageIssues: Bool { session.canManageIssues }
    var commandsActive: Bool { shell.commandsActive }
    var settings: ShellSettings? { shell.settings }

    func profileName(_ id: Int) -> String? { shell.profileNames[id] }
    var railStyle: RailStyle { RailStyle(rawValue: settings?.libraryRailStyle ?? "") ?? .current }
    var railConsolidate: Bool { settings?.libraryRailConsolidate ?? false }
    var animationsEnabled: Bool { settings?.animationsEnabled ?? true }
    var canApproveRequests: Bool { session.canApproveRequests }

    /// Requester accounts get the web's reduced nav.
    var requestScoped: Bool { session.requestScoped }
}
