import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

/// Avatar menu › Widget diagnostics: what the Home Screen widgets did on their
/// last reloads, readable on the phone (no Mac, no device logs). A widget with
/// no runs listed was never asked for a timeline; a run left `never finished`
/// was killed mid-reload; `not drawn` means its entry never rendered.
struct WidgetDiagnosticsView: View {
    static var openAtLaunch: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WIDGET_DIAG"] != nil
        #else
        false
        #endif
    }

    static var screenshotSamples: Bool {
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_WIDGET_DIAG"] == "sample"
    }

    @Environment(\.dismiss) private var dismiss
    @State private var report: WidgetDiagnosticsReport?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                if let report {
                    WidgetDiagnosticsSections(report: report)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
                actions
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Widget diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .task { report = await WidgetDiagnosticsReport.load() }
    }

    private var actions: some View {
        Section {
            Button("Reload widgets", systemImage: "arrow.clockwise") { reload() }
            Button(copied ? "Copied" : "Copy report", systemImage: copied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = report?.text
                copied = true
            }
            .disabled(report == nil)
        } footer: {
            Text("Reload asks iOS to refresh every widget now; the runs appear here a few seconds later.")
        }
    }

    private func reload() {
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            try? await Task.sleep(for: .seconds(4))
            report = await WidgetDiagnosticsReport.load()
        }
    }
}

/// The report's sections: installed widgets, recent runs, sign-in sharing.
private struct WidgetDiagnosticsSections: View {
    let report: WidgetDiagnosticsReport

    var body: some View {
        Section("On the Home Screen") {
            if report.installed.isEmpty {
                Text(report.installedError.map { "Couldn't ask iOS: \($0)" } ?? "No fusionha widgets added")
                    .foregroundStyle(Theme.mut)
            }
            ForEach(report.installed, id: \.self) { Text($0).font(.system(.callout, design: .monospaced)) }
        }
        Section {
            if report.runs.isEmpty {
                Text("No widget has run since this build was installed.").foregroundStyle(Theme.mut)
            }
            ForEach(report.runs) { WidgetRunRow(record: $0, now: report.loadedAt) }
        } header: {
            Text("Last runs")
        } footer: {
            Text("Never finished: iOS stopped the widget mid-reload. Not drawn: its entry never rendered.")
        }
        Section("Sign-in sharing") {
            Text(report.sharing).font(.system(.caption, design: .monospaced))
            Text(report.keychain).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.mut)
        }
    }
}
