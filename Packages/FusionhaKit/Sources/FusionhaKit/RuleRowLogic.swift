import Foundation

/// A root a free-space guard checks (web `rule-format.ts` `GuardRoot`):
/// `freeGb` nil is unknown (inaccessible or unreported), which the server
/// holds too.
public struct GuardRoot: Sendable, Hashable {
    public let path: String
    public let freeGb: Int?
    /// Tiers whose Add-defaults use this root.
    public let tiers: [QualityTier]

    public init(path: String, freeGb: Int?, tiers: [QualityTier]) {
        self.path = path
        self.freeGb = freeGb
        self.tiers = tiers
    }

    /// "/media/movies · 412 GB free" or "… · free space unknown".
    public var line: (path: String, free: String) {
        (path, freeGb.map { "\($0) GB free" } ?? "free space unknown")
    }

    /// Every root an Add-defaults slot uses, with the tiers that use it
    /// (web `useGuardRoots`). Roots no slot uses are left out.
    public static func from(roots: [RootFolder], slots: [AddDefaultSlot]) -> [GuardRoot] {
        roots.compactMap { r in
            var tiers: [QualityTier] = []
            for s in slots where s.rootFolderId == r.id && !tiers.contains(s.tier) { tiers.append(s.tier) }
            guard !tiers.isEmpty else { return nil }
            let unknown = r.accessible == false || r.freeSpace == nil
            return GuardRoot(path: r.path, freeGb: unknown ? nil : Int((r.freeSpace ?? 0) / 1_000_000_000), tiers: tiers)
        }
    }

    /// The roots one guard checks: all of them, or only its tier's.
    public static func roots(_ all: [GuardRoot], for tier: QualityTier?) -> [GuardRoot] {
        guard let tier else { return all }
        return all.filter { $0.tiers.contains(tier) }
    }
}

/// A rule row's words (web `RuleRow`): who it covers, which version, and why
/// a control is off.
public enum RuleRowCopy {
    public static let needsManage = "Needs Manage settings"
    public static let guardAdminOnly = "Only an admin can turn off, delete or loosen a guard"
    public static let builtInOnly = "A built-in rule can only be turned on or off"

    /// "Role: Family" or "Everyone".
    public static func audience(_ rule: RequestRule) -> String {
        rule.roleName.map { "Role: \($0)" } ?? "Everyone"
    }

    public struct Reasons: Sendable, Equatable {
        public let toggle: String?
        public let edit: String?
        public let delete: String?
        public let order: String?
    }

    /// Why each control is off; nil where it's allowed. Turning a guard OFF
    /// (not on) and deleting it are admin-only loosenings.
    public static func reasons(_ rule: RequestRule, canManage: Bool, isAdmin: Bool) -> Reasons {
        let base = canManage ? nil : needsManage
        let adminOnlyGuard = rule.kind.isGuard && !isAdmin && canManage
        return Reasons(toggle: base ?? (adminOnlyGuard && rule.enabled ? guardAdminOnly : nil),
                       edit: base ?? (rule.locked ? builtInOnly : nil),
                       delete: base ?? (adminOnlyGuard ? guardAdminOnly : (rule.locked ? builtInOnly : nil)),
                       order: base)
    }
}
