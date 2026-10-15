import Foundation

/// Labels and small rules for the report sheet, the issue thread and "My
/// issues" (web `report-format.ts`, `situation.ts`, `marker.ts`).
public enum IssueFormat {
    public struct Problem: Sendable, Hashable {
        public let value: String
        public let label: String
        /// An SF Symbol standing in for the web's icon.
        public let symbol: String
        public let seriesOnly: Bool
    }

    public static let problems: [Problem] = [
        Problem(value: "WONT_PLAY", label: "Won’t play", symbol: "play.slash", seriesOnly: false),
        Problem(value: "LANGUAGE", label: "Wrong language", symbol: "character.bubble", seriesOnly: false),
        Problem(value: "MISSING_EPS", label: "Missing episodes", symbol: "tv", seriesOnly: true),
        Problem(value: "NOT_IN_PLEX", label: "Not in Plex", symbol: "eye.slash", seriesOnly: false),
        Problem(value: "LOOKS_BAD", label: "Looks bad", symbol: "photo", seriesOnly: false),
        Problem(value: "OTHER", label: "Something else", symbol: "bubble.left", seriesOnly: false),
    ]

    public static func problems(series: Bool) -> [Problem] { problems.filter { series || !$0.seriesOnly } }
    public static func problemLabel(_ value: String) -> String { problems.first { $0.value == value }?.label ?? "Something else" }
    public static func problemSymbol(_ value: String) -> String { problems.first { $0.value == value }?.symbol ?? "bubble.left" }

    /// The state word a person sees; a reopened, unresolved report reads "Reopened".
    public static func stateLabel(_ state: String, reopenCount: Int = 0) -> String {
        if state == "RESOLVED" { return "Resolved" }
        if reopenCount > 0 { return "Reopened" }
        if state == "CHECKING" { return "Checking" }
        if state == "FIXING" { return "Fixing" }
        return "Open"
    }

    /// working = cyan, resolved = green, anything waiting on a person = amber.
    public enum Tone: Sendable, Hashable { case working, resolved, attention, neutral }

    public static func stateTone(_ state: String, reopenCount: Int = 0) -> Tone {
        if state == "RESOLVED" { return .resolved }
        if reopenCount > 0 { return .attention }
        if isWorking(state) { return .working }
        return .attention
    }

    public static func isWorking(_ state: String) -> Bool { state == "CHECKING" || state == "FIXING" }

    /// Why a choice can't be taken.
    public static func permissionHint(_ permission: String?, manager: Bool = false, choiceId: String? = nil,
                                      dailyLimit: Int? = nil) -> String {
        let p = permission ?? "allowed"
        if p == "rate_limited" && choiceId == "find_language_release" && !manager {
            return dailyLimit.map { "You’ve used today’s \($0) replacements" } ?? "You’ve used today’s replacements"
        }
        if p == "rate_limited" && choiceId == "request_version" && !manager { return "Used this week’s requests" }
        if choiceId == "find_language_release" && !manager {
            if p == "paused" { return "Automatic fixes are paused for this copy" }
            if p == "not_enabled" { return "Automatic fixes are turned off" }
        }
        switch p {
        case "paused": return "Paused for this copy"
        case "not_enabled": return "Not turned on for you"
        case "no_access": return manager ? "Not allowed on this title" : "Needs UHD·4K access"
        case "rate_limited": return "Used your fixes for now"
        case "admin_only": return "Only an admin can do this"
        default: return ""
        }
    }

    /// A disabled choice's line: the reason, then where to go instead.
    public static func disabledSub(_ permission: String?, manager: Bool = false, choiceId: String? = nil,
                                   dailyLimit: Int? = nil) -> String {
        let why = permissionHint(permission, manager: manager, choiceId: choiceId, dailyLimit: dailyLimit)
        if manager { return why }
        let p = permission ?? "allowed"
        if p == "rate_limited" && choiceId == "request_version" { return "\(why) · They reset on Monday." }
        if choiceId == "find_language_release" && (p == "paused" || p == "not_enabled") {
            return "\(why) · Keep this copy tells the admin."
        }
        if p == "rate_limited" { return "\(why) · They come back over the next 24 hours." }
        return "\(why) · Ask an admin below instead."
    }

    /// The button on a choice: text, symbol, and what it reads once done.
    public static func choiceButton(_ id: String) -> (text: String, symbol: String, done: String) {
        switch id {
        case "search_missing": return ("Search now", "magnifyingglass", "Searching")
        case "plex_rescan": return ("Rescan", "arrow.clockwise", "Rescan asked")
        case "request_version": return ("Request", "plus", "Requested")
        default: return ("Do this", "checkmark", "Done")
        }
    }

    /// The report a just-filed issue refers to: the caller's own, newest,
    /// preferring the same problem and version.
    public static func pickReport(_ reports: [IssueReport], problem: String? = nil, versionId: Int? = nil) -> IssueReport? {
        let mine = reports.filter { $0.mine == true }
        let pool = mine.isEmpty ? reports : mine
        let exact = pool.filter { (problem == nil || $0.problem == problem) && (versionId == nil || $0.version.id == versionId) }
        return (exact.isEmpty ? pool : exact).max { $0.id < $1.id }
    }

    public static func versionText(tier: QualityTier, edition: String?) -> String {
        edition.map { "\(tier.chipLabel) · \($0)" } ?? tier.chipLabel
    }

    /// The version the sheet starts on: HD Standard, else any HD, else the first.
    public static func defaultVersionId(_ versions: [IssueVersionRef]) -> Int? {
        let hd = versions.filter { $0.tier == .hd }
        return (hd.first { $0.edition == nil } ?? hd.first ?? versions.first)?.id
    }

    public static func scopeComplete(scope: String, season: Int?, episode: Int?) -> Bool {
        scope == "item" || (season != nil && (scope == "season" || episode != nil))
    }

    public static func isLanguageReport(_ report: IssueReport) -> Bool {
        report.choices.contains { $0.id == "find_language_release" }
    }

    /// A body-less rescan marker: the timeline leaves it out.
    public static func isMarkerLine(_ e: RequestThreadEvent) -> Bool {
        (e.body ?? "").isEmpty && e.data?.action == "rescan"
    }

    /// The thread banner's second line, per state.
    public static func bannerHint(_ state: String) -> String {
        switch state {
        case "CHECKING": return "The check usually takes a few seconds. Nothing for you to do yet."
        case "FIXING": return "We’re on it. We’ll message you when something changes."
        case "AWAITING_USER": return "Choose a fix below, or tell the admins."
        case "NEEDS_ADMIN": return "An admin will take a look."
        case "RESOLVED": return "This is resolved. Use “Didn’t help?” if it still isn’t right."
        default: return ""
        }
    }

    /// What a typed situation adds under the verdict (web `situation.ts`).
    public struct Situation: Sendable, Hashable {
        public let symbol: String
        public let tone: Tone
        public let detail: String?
        public let note: String?
    }

    public static func situation(_ value: String?) -> Situation? {
        switch value {
        case "second_check":
            return Situation(symbol: "clock", tone: .working,
                             detail: "The link to this file looked dead once. These links sometimes come back, so fusionha checks twice before it replaces anything.",
                             note: nil)
        case "inconclusive":
            return Situation(symbol: "clock", tone: .attention,
                             detail: "Nothing changes to your copy until fusionha knows for sure; it checks again every hour.",
                             note: "If a later check finds it broken, the fix starts by itself.")
        case "plays_fine":
            return Situation(symbol: "play", tone: .attention,
                             detail: "The whole file read without a problem. We’ve passed your report to an admin, who can replace it if it still won’t play for you.",
                             note: "You can’t start a replacement yourself when the file checks out.")
        case "autofix_off":
            return Situation(symbol: "exclamationmark.triangle", tone: .attention, detail: "Your copy stays as it is.", note: nil)
        case "paused":
            return Situation(symbol: "pause", tone: .attention, detail: "Your copy stays as it is.", note: nil)
        case "kept":
            return Situation(symbol: "bubble.left", tone: .neutral,
                             detail: "Nothing changed. An admin can look for another release, or resolve the report.",
                             note: "This didn’t use one of today’s replacements.")
        case "replacing": return Situation(symbol: "arrow.clockwise", tone: .working, detail: nil, note: nil)
        case "held": return Situation(symbol: "checkmark", tone: .attention, detail: nil, note: nil)
        case "swapped": return Situation(symbol: "checkmark", tone: .resolved, detail: nil, note: nil)
        default: return nil
        }
    }

    /// The fix verdict's look: the situation's, else by state.
    public static func verdictLook(_ report: IssueReport) -> (symbol: String, tone: Tone) {
        if let s = situation(report.situation) { return (s.symbol, s.tone) }
        switch report.state {
        case "FIXING": return ("arrow.clockwise", .working)
        case "NEEDS_ADMIN": return ("exclamationmark.triangle", .attention)
        case "RESOLVED": return ("checkmark", .resolved)
        default: return ("info.circle", .working)
        }
    }

    /// The check sweep's staged steps.
    public static func sweepSteps(series: Bool) -> [String] {
        let all = ["Looking at the files on disk", "Asking Plex if it can see them", "Counting the episodes"]
        return series ? all : Array(all.prefix(2))
    }
}
