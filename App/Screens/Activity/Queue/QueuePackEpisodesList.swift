import SwiftUI
import FusionhaKit

/// A pack's episodes, behind "Show the N files" (web `PackRanges`): fetched
/// only once opened (`GET /queue/{id}/pack-episodes`), each row its code,
/// title and, for a held pack, what was decided for its file.
struct QueuePackEpisodesList: View {
    let downloadId: Int
    let fileCount: Int?
    @Environment(AppModel.self) private var model
    @State private var open = false
    @State private var episodes: [QueuePackEpisode] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                open.toggle()
                if open && episodes.isEmpty { Task { await load() } }
            } label: {
                Label(open ? "Hide files" : "Show the \(fileCount.map { "\($0) " } ?? "")files",
                      systemImage: open ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.i2)
                    .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
            if open {
                if loading && episodes.isEmpty {
                    ProgressView().controlSize(.small)
                }
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(episodes) { e in
                        HStack(spacing: 8) {
                            Text(code(e)).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.mut)
                            Text(e.title ?? "Episode \(e.absolute ?? e.episode)").font(.system(size: 12.5)).foregroundStyle(Theme.txt).lineLimit(1)
                            Spacer(minLength: 0)
                            if let o = e.outcome { Text(o.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(tone(o)) }
                        }
                    }
                }
            }
        }
    }

    private func code(_ e: QueuePackEpisode) -> String {
        if let abs = e.absolute, e.season == 0 || e.episode == 0 { return String(format: "%03d", abs) }
        return String(format: "S%02dE%02d", e.season, e.episode)
    }

    private func tone(_ o: QueuePackOutcome) -> Color {
        switch o {
        case .imported, .ready: return Theme.done
        case .held: return Theme.miss
        default: return Theme.dim
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        loading = true
        defer { loading = false }
        var offset = 0
        var all: [QueuePackEpisode] = []
        while let page = try? await client.queuePackEpisodes(downloadId: downloadId, offset: offset, limit: 500) {
            all += page.items
            offset += page.items.count
            if page.items.isEmpty || offset >= page.total { break }
        }
        episodes = all
    }
}
