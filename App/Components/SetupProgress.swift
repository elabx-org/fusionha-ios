import SwiftUI
import FusionhaKit

// MARK: - Store (app/SetupProgressProvider.tsx + lib/api/setup-progress.ts)

/// The caller's setups (`GET /api/v1/library/setups`), polled every 2s while
/// anything is setting up and every 20s otherwise, plus the pill's own UI state
/// so every tab shows the same pill.
@MainActor
@Observable
final class SetupProgress {
    /// How long a finished setup lingers before the pill tidies it away.
    static let autoDismiss: Duration = .seconds(5)

    private(set) var list = TitleSetupList()
    /// Per-title slots for the posters (`SetupSlots`).
    let slots = SetupSlots()
    /// Setup instances the user dismissed, or that finished and timed out.
    var dismissed: Set<String> = []
    var expanded = false {
        didSet { expanded ? cancelDismissals() : scheduleDismissals() }
    }

    @ObservationIgnored private(set) var lastRefresh = Date.distantPast
    @ObservationIgnored private var signatures: [Int: String] = [:]
    @ObservationIgnored private var primed = false
    @ObservationIgnored private var timers: [String: Task<Void, Never>] = [:]

    /// A setup INSTANCE: adding another version to a finished title starts a new one.
    static func key(_ setup: TitleSetup) -> String { "\(setup.itemId):\(setup.startedAt ?? "")" }

    var visible: [TitleSetup] { list.setups.filter { !dismissed.contains(Self.key($0)) } }

    /// The poster's shimmer + ring read this: only while the setup is still running.
    func activeSetup(for itemId: Int) -> TitleSetup? {
        list.setups.first { $0.itemId == itemId && $0.isActive }
    }

    /// Fetches the list. Returns true when a step finished since the last poll,
    /// so the caller reloads the library (the title's tree or files changed).
    func refresh(client: APIClient) async -> Bool {
        lastRefresh = Date()
        guard let next = try? await client.setups() else { return false }
        var changed = false
        var seen = Set<Int>()
        for setup in next.setups {
            seen.insert(setup.itemId)
            let signature = setup.steps.filter { $0.status.finished }.map(\.key).joined(separator: "|")
            if primed && signatures[setup.itemId] != signature { changed = true }
            signatures[setup.itemId] = signature
        }
        signatures = signatures.filter { seen.contains($0.key) }
        primed = true
        if next != list { list = next; slots.update(next) }
        let current = Set(next.setups.map(Self.key))
        if !dismissed.isSubset(of: current) { dismissed = dismissed.intersection(current) }
        if visible.isEmpty, expanded { expanded = false }
        #if DEBUG
        applyScreenshotMode()
        #endif
        scheduleDismissals()
        return changed
    }

    #if DEBUG
    /// CI screenshots (`FUSIONHA_SCREENSHOT_SETUP`): `steps` opens the running
    /// setup's panel, `result` the finished one's, `multi` both as rows.
    private func applyScreenshotMode() {
        guard let mode = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SETUP"], !mode.isEmpty else { return }
        let hide = Set(list.setups.filter { setup in
            if mode == "steps" { return !setup.isActive }
            if mode == "result" { return setup.isActive }
            return false
        }.map(Self.key))
        if dismissed != hide { dismissed = hide }
        if !expanded { expanded = true }
    }
    #endif

    func dismissAll() {
        dismissed = Set(list.setups.map(Self.key))
        expanded = false
    }

    private func scheduleDismissals() {
        guard !expanded else { return }
        for setup in list.setups where setup.finishedAt != nil {
            let key = Self.key(setup)
            guard !dismissed.contains(key), timers[key] == nil else { continue }
            timers[key] = Task { [weak self] in
                try? await Task.sleep(for: Self.autoDismiss)
                guard !Task.isCancelled, let self else { return }
                timers[key] = nil
                dismissed.insert(key)
            }
        }
    }

    private func cancelDismissals() {
        timers.values.forEach { $0.cancel() }
        timers = [:]
    }
}
