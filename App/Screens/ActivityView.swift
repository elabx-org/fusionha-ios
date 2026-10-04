import SwiftUI
import FusionhaKit

enum ActivityTab: Hashable {
    case queue, history, blocklist
}

/// The web's Activity page: header, title search and the Queue / History /
/// Blocklist tabs.
struct ActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: ActivityTab = .queue
    @State private var query = ""
    @State private var processing = false
    @State private var history: [HistoryEntry] = []
    @State private var blocklist: [BlocklistEntry] = []
    @State private var listError: String?
    @State private var loadingList = false

    private var filteredQueue: [QueueItem] {
        guard !query.isEmpty else { return model.queue }
        return model.queue.filter {
            $0.title.localizedCaseInsensitiveContains(query) || ($0.releaseTitle ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(title: "Activity", subtitle: subtitle) {
                        SquareIconButton(systemImage: "arrow.triangle.2.circlepath", label: "Process queue now") {
                            Task {
                                processing = true
                                try? await model.client?.processQueue()
                                await model.refreshQueue()
                                processing = false
                            }
                        }
                        .symbolEffect(.rotate, isActive: processing)
                    }
                    WebSearchField(placeholder: "Search by title…", text: $query)
                    SegmentedPills(options: [(ActivityTab.queue, "Queue"), (.history, "History"), (.blocklist, "Blocklist")],
                                   selection: $tab, style: .plain, fill: true)
                    switch tab {
                    case .queue: queue
                    case .history: historyList
                    case .blocklist: blocklistList
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .refreshable { await refresh() }
        }
        .task(id: "\(tab)|\(query)") {
            guard tab != .queue else { return }
            try? await Task.sleep(for: .milliseconds(250))
            await loadList()
        }
    }

    private var subtitle: String {
        model.queueTotal == 0 ? "No active downloads" : "\(model.queueTotal) active download\(model.queueTotal == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var queue: some View {
        if filteredQueue.isEmpty {
            if model.queueError != nil {
                EmptyBox(message: "The download queue could not be loaded. Check the backend and try again.")
            } else if !query.isEmpty {
                EmptyBox(message: "No downloads match “\(query)”.")
            } else {
                EmptyBox(message: "Nothing downloading. Grabs show up here while they download and import.")
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredQueue) { item in
                    QueueCard(item: item)
                        .onTapGesture { model.open(item.mediaItemId) }
                }
            }
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if history.isEmpty {
            if loadingList {
                ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                EmptyBox(message: listError == nil ? "No history yet." : "History could not be loaded.")
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(history) { entry in
                    HistoryRow(entry: entry)
                        .onTapGesture { if let id = entry.mediaItemId { model.open(id) } }
                }
            }
        }
    }

    @ViewBuilder
    private var blocklistList: some View {
        if blocklist.isEmpty {
            if loadingList {
                ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                EmptyBox(message: listError == nil ? "The blocklist is empty." : "The blocklist could not be loaded.")
            }
        } else {
            LazyVStack(spacing: 10) {
                ForEach(blocklist) { BlocklistRow(entry: $0) }
            }
        }
    }

    private func refresh() async {
        if tab == .queue { await model.refreshQueue() } else { await loadList() }
    }

    private func loadList() async {
        guard let client = model.client else { return }
        loadingList = true
        defer { loadingList = false }
        do {
            switch tab {
            case .queue: break
            case .history: history = try await client.history(query: query).items
            case .blocklist: blocklist = try await client.blocklist(query: query).items
            }
            listError = nil
        } catch {
            listError = error.localizedDescription
        }
    }
}

/// One download in the queue: poster, title + tier, progress and phase.
struct QueueCard: View {
    let item: QueueItem

    private var tint: Color { item.stalled ? Theme.stuck : Theme.grab }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .frame(width: 46, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    TierPill(tier: item.tier)
                }
                if let label = item.episodeLabel {
                    Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if let release = item.releaseTitle {
                    Text(release)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                RailBar(progress: Int(item.progress), color: tint, state: .downloading)
                HStack {
                    Text(phaseText).foregroundStyle(tint)
                    Spacer()
                    Text("\(Int(item.progress))% · \(Format.bytes(item.sizeleft)) left")
                        .monospacedDigit()
                        .foregroundStyle(Theme.mut)
                }
                .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                .fill(tint.opacity(0.8))
                .frame(height: 2)
                .padding(.horizontal, 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var phaseText: String {
        if item.stalled { return "Stalled" }
        return (item.phase ?? item.status).replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    private var color: Color {
        let type = entry.eventType.uppercased()
        if type.contains("FAIL") || type.contains("DELETE") || type.contains("REJECT") { return Theme.danger }
        if type.contains("IMPORT") || type.contains("DOWNLOADED") { return Theme.done }
        if type.contains("GRAB") { return Theme.grab }
        if type.contains("UPGRADE") { return Theme.edition }
        return Theme.mut
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.itemTitle ?? "Unknown title")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let tier = entry.tier { TierPill(tier: tier) }
                    Spacer(minLength: 0)
                    Text(Format.relative(entry.createdAt))
                        .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
                }
                Text(entry.eventLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                if let source = entry.sourceTitle {
                    Text(source)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(2)
                }
                if let chips = entry.chips, !chips.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.mut)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
                        }
                    }
                }
            }
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
        .contentShape(Rectangle())
    }
}

struct BlocklistRow: View {
    let entry: BlocklistEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(entry.posterUrl, to: "w154"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.itemTitle ?? "Unknown title")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(Format.relative(entry.createdAt)).font(.system(size: 11)).foregroundStyle(Theme.dim)
                }
                if let label = entry.episodeLabel {
                    Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Text(entry.title)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
                if let reason = entry.reason {
                    Text(reason).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.danger)
                }
            }
        }
        .padding(12)
        .panel(Theme.card, radius: 14)
    }
}
