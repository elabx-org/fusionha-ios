import SwiftUI

/// Maintenance > Performance reports: how many MetricKit reports this device
/// has saved (`PerformanceReports`), a share of all of them as one file, and
/// a clear. The reports stay on the device until the owner shares them.
struct PerformanceReportsSection: View {
    @State private var count = 0
    @State private var newest: Date?
    @State private var confirmClear = false

    var body: some View {
        SettingsSection("Performance reports",
                        footer: "iOS collects these in the background: slow or frozen moments, crashes, and how smooth scrolling was. Problems arrive the next time you open the app; the rest about once a day.") {
            SettingValueRow(label: "Saved reports", description: summary) {
                MonoText("\(count)")
            }
            SettingValueRow(label: "Send reports",
                            description: "Shares every saved report as one file, for AirDrop, Mail or Files.") {
                ShareLink(item: PerformanceReportsExport(),
                          preview: SharePreview("fusionha performance reports")) {
                    Text("Share")
                }
                .buttonStyle(.web(.primary))
                .disabled(count == 0)
            }
            SettingValueRow(label: "Clear reports", description: "Deletes the saved reports from this device.") {
                Button("Clear") { confirmClear = true }
                    .buttonStyle(.web(.danger))
                    .disabled(count == 0)
            }
        }
        .alert("Clear performance reports?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                PerformanceReports.clear()
                reload()
            }
        } message: {
            Text("The \(count) saved reports are deleted from this device.")
        }
        .onAppear(perform: reload)
    }

    private var summary: String {
        guard let newest else { return "None yet." }
        return "Newest from \(newest.formatted(date: .abbreviated, time: .shortened))."
    }

    private func reload() {
        let files = PerformanceReports.files()
        count = files.count
        newest = files.first.map(PerformanceReports.modified)
    }
}
