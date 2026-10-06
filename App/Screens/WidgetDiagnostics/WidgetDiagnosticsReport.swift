import Foundation
import WidgetKit
import FusionhaKit

/// What the Widget diagnostics sheet shows: the widgets iOS has on the Home
/// Screen, the extension's last runs (from the shared keychain journal) and
/// how the sign-in is shared with it. Read off the main thread: every part is
/// keychain or WidgetKit IPC.
struct WidgetDiagnosticsReport: Sendable {
    var installed: [String] = []
    var installedError: String?
    var runs: [WidgetRunRecord] = []
    var sharing = ""
    var keychain = ""
    var loadedAt = Date()

    static func load() async -> WidgetDiagnosticsReport {
        #if DEBUG
        if WidgetDiagnosticsView.screenshotSamples { WidgetDiagnosticsSamples.seed() }
        #endif
        var report = await Task.detached(priority: .userInitiated) {
            WidgetDiagnosticsReport(runs: WidgetJournal.all(), sharing: CredentialStore.diagnostics(),
                                    keychain: CredentialStore.sharingReport())
        }.value
        do {
            let configs = try await WidgetCenter.shared.currentConfigurations()
            report.installed = configs.map { "\($0.kind) · \(WidgetJournal.name($0.family))" }.sorted()
        } catch {
            report.installedError = "\((error as NSError).domain) \((error as NSError).code)"
        }
        return report
    }

    /// The whole report as plain text, for Copy.
    var text: String {
        let now = Date()
        var lines = ["fusionha widget diagnostics · \(Bundle.main.appVersion) · \(loadedAt.formatted(.iso8601))"]
        lines.append("Installed: " + (installed.isEmpty ? (installedError ?? "none") : installed.joined(separator: ", ")))
        lines.append("Sign-in: \(sharing)")
        lines.append("Keychain: \(keychain)")
        lines.append("Runs (newest first):")
        lines += runs.map { "\($0.log.started.formatted(date: .omitted, time: .standard)) \($0.line(now: now))" }
        if runs.isEmpty { lines.append("none recorded") }
        return lines.joined(separator: "\n")
    }
}
