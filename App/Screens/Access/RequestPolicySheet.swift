import SwiftUI
import FusionhaKit

/// A person's or a role's request policy (web `RequestPolicyDialog`): which
/// versions they may request, what is approved automatically, the weekly
/// quota and auto-approval cap, the automatic-request grants (Plex
/// watchlist, Letterboxd & linked lists), and the self-service fixes on their issue
/// reports. Every field can inherit (from the role, Plex access or the
/// default); each change saves on its own (a partial PUT of that field).
struct RequestPolicySheet: View {
    enum Target { case user(Int, String), role(Int, String) }
    let target: Target
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var policy: RequestPolicy?
    @State private var error: String?
    @State private var saving = false

    private var isUser: Bool { if case .user = target { return true }; return false }
    private var name: String {
        switch target { case .user(_, let n), .role(_, let n): return n }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error { Text(error).foregroundStyle(Theme.danger).font(.footnote) }
                if let p = policy {
                    tiersSection(p)
                    limitsSection(p)
                    PolicyAutomaticSection(policy: p, isUser: isUser) { fields in save(fields) }
                    selfServiceSection(p)
                    if let members = p.members {
                        Section {
                            Text("\(members) \(members == 1 ? "member" : "members")"
                                 + (p.tierFollowers.map { " · \($0) follow the role’s versions" } ?? ""))
                                .foregroundStyle(Theme.mut)
                        }
                    }
                } else if error == nil {
                    ProgressView()
                }
            }
            .disabled(saving)
            .navigationTitle("Request policy · \(name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
        .presentationDetents([.large])
    }

    // MARK: Sections

    private func tiersSection(_ p: RequestPolicy) -> some View {
        Section {
            Picker("May request", selection: Binding(get: { TierChoice(p.allowedTiers) }, set: { c in save(["allowed_tiers": c.json]) })) {
                ForEach(TierChoice.allCases, id: \.self) { Text($0.label(isUser: isUser)).tag($0) }
            }
            if isUser {
                Picker("Approved automatically", selection: Binding(get: { TierChoice(p.autoApproveTiers, emptyIsNone: true) },
                                                                    set: { c in save(["auto_approve_tiers": c.grantJSON]) })) {
                    ForEach([TierChoice.none, .hd, .uhd, .both], id: \.self) { Text($0.grantLabel).tag($0) }
                }
                Picker("Quality", selection: Binding(get: { p.requestQualityMode ?? "choose" }, set: { save(["request_quality_mode": .string($0)]) })) {
                    Text("They choose").tag("choose")
                    Text("Automatic").tag("auto")
                }
            }
        } header: {
            Text("Versions")
        } footer: {
            Text(effectiveTiers(p))
        }
    }

    private func limitsSection(_ p: RequestPolicy) -> some View {
        Section {
            limitPicker("Requests per week", key: "quota_per_week", stored: p.quotaPerWeek, effective: p.effective?.quotaPerWeek)
            limitPicker("Auto-approved per week", key: "auto_requests_per_week", stored: p.autoRequestsPerWeek,
                        effective: p.effective?.autoRequestsPerWeek)
        } header: {
            Text("Limits")
        } footer: {
            Text([p.source("quota_per_week").map { "Quota: \($0)" }, p.source("auto_requests_per_week").map { "Cap: \($0)" }]
                .compactMap { $0 }.joined(separator: " · "))
        }
    }

    private func limitPicker(_ title: String, key: String, stored: Int?, effective: Int?) -> some View {
        Picker(title, selection: Binding(get: { stored ?? -1 }, set: { n in save([key: n < 0 ? .null : .int(n)]) })) {
            Text("Inherit" + (effective.map { " (\($0 == 0 ? "unlimited" : "\($0)"))" } ?? " (unlimited)")).tag(-1)
            Text("Unlimited").tag(0)
            ForEach([1, 2, 3, 5, 10, 20, 50], id: \.self) { Text("\($0)").tag($0) }
        }
    }

    private func selfServiceSection(_ p: RequestPolicy) -> some View {
        Section {
            triToggle("Search for missing episodes", key: "ss_search_missing", stored: p.ssSearchMissing, effective: p.effective?.ssSearchMissing)
            triToggle("Ask Plex to rescan", key: "ss_plex_rescan", stored: p.ssPlexRescan, effective: p.effective?.ssPlexRescan)
            triToggle("Request another version", key: "ss_request_version", stored: p.ssRequestVersion, effective: p.effective?.ssRequestVersion)
        } header: {
            Text("Self-service fixes")
        } footer: {
            Text("What they may run themselves from an issue report, within the daily limit.")
        }
    }

    private func triToggle(_ title: String, key: String, stored: Bool?, effective: Bool?) -> some View {
        Picker(title, selection: Binding(get: { stored.map { $0 ? 1 : 0 } ?? -1 },
                                          set: { v in save([key: v < 0 ? .null : .bool(v == 1)]) })) {
            Text("Inherit (\(effective == false ? "off" : "on"))").tag(-1)
            Text("On").tag(1)
            Text("Off").tag(0)
        }
    }

    private func effectiveTiers(_ p: RequestPolicy) -> String {
        let tiers = p.effective?.allowedTiers
        let what = tiers.map { $0.isEmpty ? "any version" : $0.map(\.chipLabel).joined(separator: " and ") } ?? "any version"
        // 0.4.214: an admin's own requests auto-approve every tier (inherited_from "admin").
        return "Today: \(what)" + (p.source("allowed_tiers").map { " · \($0)" } ?? "")
            + (p.inheritedLayer("auto_approve_tiers") == "admin" ? " · Admin: every version approved automatically" : "")
    }

    // MARK: Load and save

    private func load() async {
        guard let client = model.client else { return }
        do {
            switch target {
            case .user(let id, _): policy = try await client.userRequestPolicy(id: id)
            case .role(let id, _): policy = try await client.roleRequestPolicy(id: id)
            }
            error = nil
        } catch {
            self.error = ErrorCopy.message(for: error, fallback: "Couldn’t load the request policy.")
        }
    }

    private func save(_ fields: [String: SettingsJSON]) {
        Task {
            guard let client = model.client else { return }
            saving = true
            defer { saving = false }
            do {
                switch target {
                case .user(let id, _): policy = try await client.putRequestPolicy(userId: id, fields)
                case .role(let id, _): policy = try await client.putRequestPolicy(roleId: id, fields)
                }
                error = nil
            } catch {
                self.error = ErrorCopy.message(for: error, fallback: "Couldn’t save the change.")
            }
        }
    }
}

/// The version picker's choices: inherit (nil), any, HD only, 4K only, both.
private enum TierChoice: CaseIterable, Hashable {
    case inherit, any, hd, uhd, both, none

    static var allCases: [TierChoice] { [.inherit, .any, .hd, .uhd, .both] }

    init(_ tiers: [QualityTier]?, emptyIsNone: Bool = false) {
        guard let tiers else { self = emptyIsNone ? .none : .inherit; return }
        let set = Set(tiers)
        if set.isEmpty { self = emptyIsNone ? .none : .any }
        else if set == [.hd] { self = .hd }
        else if set == [.uhd] { self = .uhd }
        else { self = .both }
    }

    func label(isUser: Bool) -> String {
        switch self {
        case .inherit: return isUser ? "Inherit" : "No role restriction"
        case .any: return "Any version"
        case .hd: return "HD·1080p only"
        case .uhd: return "UHD·4K only"
        case .both, .none: return "HD·1080p and UHD·4K"
        }
    }

    var grantLabel: String {
        switch self {
        case .hd: return "HD·1080p"
        case .uhd: return "UHD·4K"
        case .both: return "Both versions"
        default: return "Nothing"
        }
    }

    private var tiers: [QualityTier] {
        switch self {
        case .hd: return [.hd]
        case .uhd: return [.uhd]
        case .both: return [.hd, .uhd]
        default: return []
        }
    }

    var json: SettingsJSON {
        self == .inherit ? .null : .array(tiers.map { .string($0.rawValue) })
    }

    /// The auto-approve grant: nothing clears it.
    var grantJSON: SettingsJSON { self == .none ? .null : .array(tiers.map { .string($0.rawValue) }) }
}
