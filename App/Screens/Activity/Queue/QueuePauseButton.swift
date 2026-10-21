import SwiftUI
import FusionhaKit

/// Pause or resume fusionha's own downloads (0.4.205, admins): only the jobs
/// fusionha tracks pause, and new grabs wait while paused. The answer names
/// any client that couldn't pause. A toolbar item (D1): title + symbol, and
/// disabled (not swapped for a spinner) while the change is in flight.
struct QueuePauseButton: View {
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var confirm = false

    var body: some View {
        let paused = model.queuePaused
        Button(paused ? "Resume downloads" : "Pause downloads",
               systemImage: paused ? "play.fill" : "pause.fill") {
            if paused { Task { await toggle() } } else { confirm = true }
        }
        .disabled(working)
        .confirmationDialog("Pause fusionha's downloads?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Pause downloads") { Task { await toggle() } }
        } message: {
            Text("Only the downloads fusionha tracks pause; anything else in your download clients keeps going. New grabs wait until you resume.")
        }
    }

    private func toggle() async {
        working = true
        await model.toggleQueuePause()
        working = false
    }
}

extension AppModel {
    /// Pauses or resumes fusionha's downloads (`POST /api/v1/queue/pause|resume`),
    /// with the answer as a toast. Shared by Activity's toolbar and the downloads bar.
    func toggleQueuePause() async {
        guard let client else { return }
        do {
            let result = queuePaused ? try await client.resumeQueue() : try await client.pauseQueue()
            queuePaused = result.paused
            let failed = result.clients.contains { !$0.ok }
            toast(result.summary, title: result.paused ? "Downloads paused" : "Downloads resumed",
                  variant: failed ? .warning : .success)
            await refreshQueue()
        } catch {
            toast(ErrorCopy.message(for: error, fallback: "Couldn't change the queue. Try again."),
                  title: "Downloads", variant: .error)
        }
    }
}
