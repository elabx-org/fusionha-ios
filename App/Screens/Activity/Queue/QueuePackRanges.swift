import SwiftUI
import FusionhaKit

/// A pack's linked / linking / waiting ranges, or a held pack's outcome runs
/// (web `PackRanges`). Each group shows at most 8 episodes; "Show all" lists
/// the rest lazily. The episode list (`GET /queue/{id}/pack-episodes`) is
/// fetched only once the pack is expanded.
struct QueuePackRanges: View {
    let downloadId: Int
    let model: QueuePackModel
    @Environment(AppModel.self) private var app
    @State private var episodes: [QueuePackEpisode] = []
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        let groups = model.split(episodes)
        VStack(alignment: .leading, spacing: 6) {
            if failed {
                Text("The file list couldn’t be loaded.").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            ForEach(Array(model.ranges.enumerated()), id: \.offset) { index, range in
                QueuePackRangeGroup(range: range, episodes: index < groups.count ? groups[index] : [],
                                    loading: loading, width: model.absoluteWidth,
                                    defaultOpen: range.kind == .done || (model.decided && index == 0))
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard episodes.isEmpty, let client = app.client else { loading = false; return }
        defer { loading = false }
        var offset = 0
        var all: [QueuePackEpisode] = []
        do {
            while true {
                let page = try await client.queuePackEpisodes(downloadId: downloadId, offset: offset, limit: 500)
                all += page.items
                offset += page.items.count
                if page.items.isEmpty || offset >= page.total { break }
            }
        } catch {
            failed = all.isEmpty
        }
        episodes = all
    }
}

private struct QueuePackRangeGroup: View {
    let range: QueuePackModel.Range
    let episodes: [QueuePackEpisode]
    let loading: Bool
    let width: Int?
    let defaultOpen: Bool
    @Environment(\.actReduceMotion) private var reduce
    @State private var open: Bool?
    @State private var all = false

    var body: some View {
        let isOpen = open ?? defaultOpen
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                QueuePackGlyph(style: range.kind.style)
                Text(range.kind.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt)
                rangeText
                Spacer(minLength: 4)
                if range.kind != .current { toggle(isOpen) }
            }
            .frame(minHeight: 28)
            if isOpen, range.kind != .current {
                list
            }
        }
    }

    private var rangeText: some View {
        let tail = range.kind == .current
            ? episodes.first?.title.map { " · \($0)" } ?? ""
            : " · \(range.count) file\(range.count == 1 ? "" : "s")"
        return (Text(range.label).foregroundColor(Theme.mut) + Text(tail).italic().foregroundColor(Theme.dim))
            .font(.system(size: 12, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private func toggle(_ isOpen: Bool) -> some View {
        Button {
            if reduce { open = !isOpen } else { withAnimation(.easeOut(duration: 0.16)) { open = !isOpen } }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                Text(isOpen ? "Hide" : "Show")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minWidth: 44, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        let cap = QueuePackModel.rangeCap
        let shown = all ? episodes : Array(episodes.prefix(cap))
        return LazyVStack(alignment: .leading, spacing: 3) {
            if loading && episodes.isEmpty {
                Text("Loading the file list…").font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            ForEach(shown) { row($0) }
            if !all && episodes.count > cap {
                Button("Show all \(episodes.count) · \(episodes.count - cap) more") { all = true }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 32)
            }
        }
        .padding(.leading, 18)
    }

    private func row(_ e: QueuePackEpisode) -> some View {
        HStack(spacing: 8) {
            Text(QueuePackModel.episodeLabel(e, absoluteWidth: width))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.mut)
            Text(e.title ?? "Episode \(e.absolute ?? e.episode)")
                .font(.system(size: 12.5)).foregroundStyle(Theme.txt).lineLimit(1)
            Spacer(minLength: 0)
            if let o = e.outcome {
                Text(o.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(QueuePackGlyph.tint(o.style))
            }
        }
        .frame(minHeight: 22)
    }
}
