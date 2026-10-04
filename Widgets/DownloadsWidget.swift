import AppIntents
import UIKit
import SwiftUI
import WidgetKit
import FusionhaKit

struct DownloadsEntry: TimelineEntry {
    struct Row: Hashable {
        let title: String
        let tier: QualityTier
        let fraction: Double
        let stalled: Bool
        let poster: Data?
    }

    let date: Date
    let total: Int
    let rows: [Row]
    let signedIn: Bool
    let failed: Bool

    static let placeholder = DownloadsEntry(
        date: .now, total: 2,
        rows: [
            Row(title: "Dune: Part Two", tier: .uhd, fraction: 0.62, stalled: false, poster: nil),
            Row(title: "Shōgun · S01E04", tier: .hd, fraction: 0.18, stalled: false, poster: nil),
        ],
        signedIn: true, failed: false)
}

struct DownloadsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DownloadsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DownloadsEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await Self.fetch(limit: 4)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadsEntry>) -> Void) {
        Task {
            let entry = await Self.fetch(limit: context.family == .systemLarge ? 4 : 2)
            // Refresh sooner while something is downloading; the app also reloads on change.
            let minutes = entry.total > 0 ? 15 : 60
            completion(Timeline(entries: [entry], policy: .after(.now + Double(minutes) * 60)))
        }
    }

    static func fetch(limit: Int) async -> DownloadsEntry {
        guard let client = CredentialStore.client() else {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: false, failed: false)
        }
        do {
            let page = try await client.queue(pageSize: limit)
            var rows: [DownloadsEntry.Row] = []
            for item in page.items.prefix(limit) {
                // Widgets can't use AsyncImage, so fetch small posters up front.
                var poster: Data?
                if let url = TMDBImage.resized(item.posterUrl, to: "w92") {
                    poster = try? await URLSession.shared.data(from: url).0
                }
                rows.append(.init(
                    title: item.episodeLabel.map { "\(item.title) · \($0)" } ?? item.title,
                    tier: item.tier, fraction: item.fraction, stalled: item.stalled, poster: poster))
            }
            return DownloadsEntry(date: .now, total: page.total, rows: rows, signedIn: true, failed: false)
        } catch {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
        }
    }
}

struct ProcessQueueIntent: AppIntent {
    static let title: LocalizedStringResource = "Process queue now"
    static let description = IntentDescription("Asks fusionha to check its download clients and import anything finished.")

    func perform() async throws -> some IntentResult {
        try await CredentialStore.client()?.processQueue()
        return .result()
    }
}

struct DownloadsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Downloads", provider: DownloadsProvider()) { entry in
            DownloadsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "fusionha://activity"))
        }
        .configurationDisplayName("Downloads")
        .description("What fusionha is downloading right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DownloadsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadsEntry

    var body: some View {
        if !entry.signedIn {
            VStack(spacing: 4) {
                Label("Sign in to fusionha", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.caption)
                Text("Open the app once to share your sign-in.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if family == .systemSmall {
            small
        } else {
            list
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.grab)
            Text(entry.total == 0 ? "Idle" : "\(entry.total) downloading")
                .font(.caption.weight(.semibold))
            Spacer()
            Button(intent: ProcessQueueIntent()) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            if let row = entry.rows.first {
                Text(row.title).font(.caption.weight(.semibold)).lineLimit(2)
                EditionChip(tier: row.tier)
                ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
            } else {
                Text(entry.failed ? "Server unreachable" : "Nothing downloading")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.rows.isEmpty {
                Spacer()
                Text(entry.failed ? "Server unreachable" : "Nothing downloading")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        posterView(row.poster)
                            .frame(width: 26, height: 39)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(row.title).font(.caption.weight(.semibold)).lineLimit(1)
                                EditionChip(tier: row.tier)
                            }
                            ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func posterView(_ data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(.quaternary)
        }
    }
}
