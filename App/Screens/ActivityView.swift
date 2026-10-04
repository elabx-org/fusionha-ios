import SwiftUI
import FusionhaKit

/// Activity → Queue. History, Blocklist and Tasks follow the plan.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var processing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.queue) { QueueRow(item: $0) }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
            .refreshable { await model.refreshQueue() }
            .overlay {
                if model.queue.isEmpty {
                    if let error = model.queueError {
                        ContentUnavailableView("Couldn't load the queue", systemImage: "wifi.exclamationmark", description: Text(error))
                    } else {
                        ContentUnavailableView("Queue is empty", systemImage: "arrow.down.circle",
                                               description: Text("Grabs show up here while they download and import."))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            processing = true
                            try? await model.client?.processQueue()
                            await model.refreshQueue()
                            processing = false
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, isActive: processing)
                    }
                    .accessibilityLabel("Process queue now")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) { AccountButton() }
            }
        }
    }
}

struct QueueRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    EditionChip(tier: item.tier)
                }
                if let label = item.episodeLabel {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: item.fraction)
                    .tint(item.stalled ? Theme.stuck : Theme.grab)
                HStack {
                    Text(phaseText).foregroundStyle(item.stalled ? Theme.stuck : .secondary)
                    Spacer()
                    Text("\(Int(item.progress))% · \(ByteCountFormatter.string(fromByteCount: Int64(item.sizeleft), countStyle: .file)) left")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var phaseText: String {
        if item.stalled { return "Stalled" }
        return (item.phase ?? item.status).replacingOccurrences(of: "_", with: " ").capitalized
    }
}
