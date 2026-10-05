import AppIntents
import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

// The home-screen widget views. In Shared so the app's debug widget gallery can
// host them for CI screenshots; each takes its family explicitly for the same reason.

struct ProcessQueueIntent: AppIntent {
    static let title: LocalizedStringResource = "Process queue now"
    static let description = IntentDescription("Asks fusionha to check its download clients and import anything finished.")

    func perform() async throws -> some IntentResult {
        try await CredentialStore.client()?.processQueue()
        return .result()
    }
}

// MARK: - Downloads

struct DownloadsWidgetView: View {
    let entry: DownloadsEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: entry.report)
            } else if !entry.idle {
                if family == .systemSmall { activeSmall } else { activeList }
            } else if entry.failed {
                VStack(alignment: .leading) {
                    header
                    WidgetEmptyText("Server unreachable")
                }
            } else {
                switch family {
                case .systemSmall: idleSmall
                case .systemMedium: idleMedium
                default: idleLarge
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.idle ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(entry.idle ? Theme.done : Theme.grab)
                .widgetAccentable()
            Text(entry.idle ? "Idle" : "\(entry.total) downloading")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Spacer(minLength: 0)
            Button(intent: ProcessQueueIntent()) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Process queue now")
        }
    }

    // Active

    private var activeSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            if let row = entry.rows.first {
                Text(row.title).font(.caption.weight(.semibold)).lineLimit(2)
                WidgetTierPill(tier: row.tier, status: row.stalled ? .stuck : .downloading)
                ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
            }
        }
    }

    private var activeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(Array(entry.rows.enumerated()), id: \.offset) { _, row in
                WidgetRowLink(url: WidgetLink.item(row.itemId)) {
                    HStack(spacing: 8) {
                        WidgetPoster(data: row.poster)
                            .frame(width: 26, height: 39)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(row.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Spacer(minLength: 0)
                                WidgetTierPill(tier: row.tier, status: row.stalled ? .stuck : .downloading)
                            }
                            ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // Idle: what's coming up and what just landed.

    private var idleSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let next = entry.upNext.first {
                WidgetSectionLabel("Up next")
                Spacer(minLength: 0)
                WidgetUpNextHero(row: next, posterWidth: 0)
            } else if let latest = entry.recent.first {
                WidgetSectionLabel("Recently added")
                Spacer(minLength: 0)
                WidgetRecentHero(row: latest, posterWidth: 0)
            } else {
                WidgetEmptyText("Nothing downloading")
            }
        }
    }

    private var idleMedium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if !entry.upNext.isEmpty {
                WidgetSectionLabel("Up next")
                VStack(spacing: 6) {
                    ForEach(Array(entry.upNext.prefix(2).enumerated()), id: \.offset) { _, row in
                        WidgetUpNextRow(row: row, posterHeight: 36)
                    }
                }
                Spacer(minLength: 0)
            } else if !entry.recent.isEmpty {
                WidgetSectionLabel("Recently added")
                WidgetPosterStrip(rows: Array(entry.recent.prefix(5)), columns: 5, showsTitle: false)
                Spacer(minLength: 0)
            } else {
                WidgetEmptyText("Nothing downloading")
            }
        }
    }

    private var idleLarge: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.upNext.isEmpty && entry.recent.isEmpty {
                WidgetEmptyText("Nothing downloading")
            } else {
                if !entry.upNext.isEmpty {
                    WidgetSectionLabel("Up next")
                    VStack(spacing: 6) {
                        ForEach(Array(entry.upNext.prefix(3).enumerated()), id: \.offset) { _, row in
                            WidgetUpNextRow(row: row, posterHeight: 36)
                        }
                    }
                }
                if !entry.recent.isEmpty {
                    WidgetSectionLabel("Recently added")
                        .padding(.top, entry.upNext.isEmpty ? 0 : 4)
                    WidgetPosterStrip(rows: Array(entry.recent.prefix(5)), columns: 5, showsTitle: false)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Up next

struct UpNextWidgetView: View {
    let entry: UpNextEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else {
                VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                    WidgetHeader(icon: "calendar", title: "Up next", tint: Theme.unaired)
                    if entry.rows.isEmpty {
                        WidgetEmptyText(entry.failed ? "Server unreachable" : "Nothing airing soon")
                    } else {
                        switch family {
                        case .systemSmall:
                            Spacer(minLength: 0)
                            WidgetUpNextHero(row: entry.rows[0], posterWidth: 0)
                        case .systemMedium:
                            VStack(spacing: 6) {
                                ForEach(Array(entry.rows.prefix(3).enumerated()), id: \.offset) { _, row in
                                    WidgetUpNextRow(row: row, posterHeight: 30)
                                }
                            }
                            Spacer(minLength: 0)
                        default:
                            largeList
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    /// Rows under day headings (`Today`, `Tomorrow`, `Thu`), times on the rows.
    private var largeList: some View {
        let rows = Array(entry.rows.prefix(6))
        let days = rows.map { WidgetFeeds.whenLabel($0.item.airDate, hasTime: false) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 || days[index] != days[index - 1] {
                    Text(days[index].uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                        .padding(.top, index == 0 ? 0 : 2)
                }
                WidgetUpNextRow(row: row, posterHeight: 36, timeOnly: true)
            }
        }
    }
}

// MARK: - Recently added

struct RecentWidgetView: View {
    let entry: RecentEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.signedIn {
                WidgetSignInPrompt(report: "")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeader(icon: "sparkles.tv", title: "Recently added", tint: Theme.done)
                    if entry.rows.isEmpty {
                        WidgetEmptyText(entry.failed ? "Server unreachable" : "Nothing imported yet")
                    } else {
                        switch family {
                        case .systemSmall:
                            Spacer(minLength: 0)
                            WidgetRecentHero(row: entry.rows[0], posterWidth: 46)
                        case .systemMedium:
                            WidgetPosterStrip(rows: Array(entry.rows.prefix(5)), columns: 5, showsTitle: false)
                            Spacer(minLength: 0)
                        default:
                            WidgetPosterStrip(rows: Array(entry.rows.prefix(4)), columns: 4, showsTitle: true)
                            WidgetPosterStrip(rows: Array(entry.rows.dropFirst(4).prefix(4)), columns: 4, showsTitle: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Pieces

/// `HD` / `4K` in the tier colour (HD purple, 4K cyan) with a status dot
/// coloured through `EditionStatus.color`, like the calendar's edition rails.
struct WidgetTierPill: View {
    let tier: QualityTier
    var status: EditionStatus?

    var body: some View {
        HStack(spacing: 3) {
            if let status {
                Circle().fill(status.color).frame(width: 5, height: 5)
            }
            Text(tier.pill)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(tier.color)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1.5)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tier.color.opacity(0.5), lineWidth: 0.75))
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.chipLabel)\(status.map { ", \($0.label)" } ?? "")")
    }
}

struct WidgetTierPills: View {
    let editions: [(tier: QualityTier, status: EditionStatus?)]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(editions.enumerated()), id: \.offset) { _, edition in
                WidgetTierPill(tier: edition.tier, status: edition.status)
            }
        }
        .fixedSize()
    }
}

extension UpNextItem {
    var pills: [(tier: QualityTier, status: EditionStatus?)] {
        editions.map { (tier: $0.tier, status: $0.status.editionStatus) }
    }
}

extension RecentImport {
    var pills: [(tier: QualityTier, status: EditionStatus?)] {
        tiers.map { (tier: $0, status: EditionStatus.downloaded) }
    }
}

/// A clean poster (no text on art) or the web's dark gradient placeholder.
struct WidgetPoster: View {
    let data: Data?
    var radius: CGFloat = 4

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "film").font(.caption2).foregroundStyle(.tertiary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct WidgetHeader: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
        .widgetAccentable()
    }
}

struct WidgetSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct WidgetEmptyText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Wraps a row in a `Link` when it has somewhere to go (medium and large only:
/// small widgets open their `widgetURL`).
struct WidgetRowLink<Content: View>: View {
    let url: URL?
    @ViewBuilder var content: Content

    var body: some View {
        // Plain, so row text keeps the widget's colours instead of the link tint.
        if let url {
            // A rectangular content shape so the whole row (gaps included) is
            // the tap region, not only its drawn pixels.
            Link(destination: url) { content.foregroundStyle(.primary).contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Poster, title, `S1·E5 · Today · 9:00 PM`, and the edition pills.
struct WidgetUpNextRow: View {
    let row: UpNextRow
    var posterHeight: CGFloat = 36
    var timeOnly = false

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 8) {
                WidgetPoster(data: row.poster)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(subtitle(item))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: item.pills)
            }
        }
    }

    private func subtitle(_ item: UpNextItem) -> String {
        let when: String
        if timeOnly {
            when = item.hasTime ? CalendarMath.clock(item.airDate) : "All day"
        } else {
            when = WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime)
        }
        return "\(item.code) · \(when)"
    }
}

/// The small family's single item: title, code and time, pills.
struct WidgetUpNextHero: View {
    let row: UpNextRow
    var posterWidth: CGFloat

    var body: some View {
        let item = row.item
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.unaired)
                .lineLimit(1)
            WidgetTierPills(editions: item.pills).padding(.top, 2)
        }
    }
}

/// The small family's latest import: optional poster, title, pills, `3h ago`.
struct WidgetRecentHero: View {
    let row: RecentImportRow
    var posterWidth: CGFloat

    var body: some View {
        let item = row.item
        HStack(alignment: .bottom, spacing: 8) {
            if posterWidth > 0 {
                WidgetPoster(data: row.poster, radius: 6)
                    .frame(width: posterWidth, height: posterWidth * 1.5)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(posterWidth > 0 ? 3 : 2)
                if let at = item.importedAt {
                    Text(WidgetFeeds.agoLabel(at) + (item.count > 1 ? " · \(item.count) files" : ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                WidgetTierPills(editions: item.pills).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A row of posters with their edition pills (and titles on the large family).
struct WidgetPosterStrip: View {
    let rows: [RecentImportRow]
    let columns: Int
    let showsTitle: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<columns, id: \.self) { index in
                if index < rows.count {
                    tile(rows[index])
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// The whole tile (poster, title, pills) is one link to the title. The poster
    /// sits on a solid frame and the label carries a rectangular content shape: a
    /// `Color.clear` base with the poster only in an overlay left the tile without
    /// a tap region, so taps fell through to the widget's URL (Activity on the
    /// Downloads widget). A row with no item id opens Library, never Activity.
    private func tile(_ row: RecentImportRow) -> some View {
        Link(destination: WidgetLink.item(row.item.itemId, fallback: .library)) {
            VStack(alignment: .leading, spacing: 4) {
                Theme.card
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay(WidgetPoster(data: row.poster, radius: 6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                if showsTitle {
                    Text(row.item.title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                }
                WidgetTierPills(editions: row.item.pills)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WidgetSignInPrompt: View {
    let report: String

    var body: some View {
        VStack(spacing: 4) {
            Label("Sign in to fusionha", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
            Text("Open the app once to share your sign-in.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Shows why this widget can't see the app's sign-in (App Group,
            // team keychain), so a re-signed build can be checked on device.
            if !report.isEmpty {
                Text(report)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The widgets' background: the app's dark panel (the system swaps it out in
/// the accented and clear renderings).
extension View {
    func fusionhaWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(colors: [Theme.panel, Theme.bg], startPoint: .top, endPoint: .bottom)
        }
    }
}
