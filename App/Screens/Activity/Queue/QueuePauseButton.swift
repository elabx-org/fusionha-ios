import SwiftUI
import FusionhaKit

/// Pause or resume fusionha's own downloads (0.4.205, admins): only the jobs
/// fusionha tracks pause, and new grabs wait while paused. The answer names
/// any client that couldn't pause.
struct QueuePauseButton: View {
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var confirm = false

    var body: some View {
        let paused = model.queuePaused
        Button {
            if paused { Task { await toggle() } } else { confirm = true }
        } label: {
            Group {
                if working {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(paused ? Theme.done : Theme.txt)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassControl()
        .disabled(working)
        .accessibilityLabel(paused ? "Resume downloads" : "Pause downloads")
        .confirmationDialog("Pause fusionha's downloads?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Pause downloads") { Task { await toggle() } }
        } message: {
            Text("Only the downloads fusionha tracks pause; anything else in your download clients keeps going. New grabs wait until you resume.")
        }
    }

    private func toggle() async {
        guard let client = model.client else { return }
        working = true
        defer { working = false }
        do {
            let result = model.queuePaused ? try await client.resumeQueue() : try await client.pauseQueue()
            model.queuePaused = result.paused
            let failed = result.clients.contains { !$0.ok }
            model.toast(result.summary, title: result.paused ? "Downloads paused" : "Downloads resumed",
                        variant: failed ? .warning : .success)
            await model.refreshQueue()
        } catch {
            model.toast(ErrorCopy.message(for: error, fallback: "Couldn't change the queue. Try again."),
                        title: "Downloads", variant: .error)
        }
    }
}
