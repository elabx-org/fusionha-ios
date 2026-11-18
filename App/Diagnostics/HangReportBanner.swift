import SwiftUI
import UIKit

/// The launch after a freeze (`HangRecorder`): a glass capsule at the top of
/// the window offers the report. Copy puts it on the clipboard for the owner
/// to send on; either button deletes it, so it shows once.
struct HangReportBanner: View {
    @State private var report: String?
    @State private var copied = false

    var body: some View {
        Group {
            if let report {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(report.hasPrefix("fusionha rescued") ? "A title got stuck last time" : "fusionha froze last time")
                            .font(.subheadline.weight(.semibold))
                        Text(copied ? "Report copied to the clipboard" : "A report of where it got stuck is ready")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if !copied {
                        Button("Copy report") {
                            UIPasteboard.general.string = report
                            copied = true
                            discard()
                            Task {
                                try? await Task.sleep(for: .seconds(2.5))
                                withAnimation { self.report = nil }
                            }
                        }
                        .buttonStyle(.glassProminent)
                    }
                    Button {
                        discard()
                        withAnimation { self.report = nil }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Dismiss")
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .glassEffect(in: .capsule)
                // On the open Duo it stays on the left page, clear of the fold.
                .frame(maxWidth: 440)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            report = try? String(contentsOf: HangRecorder.reportURL, encoding: .utf8)
        }
    }

    private func discard() {
        try? FileManager.default.removeItem(at: HangRecorder.reportURL)
    }
}
