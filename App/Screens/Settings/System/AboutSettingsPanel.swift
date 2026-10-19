import SwiftUI
import WebKit
import FusionhaKit

// MARK: About

struct AboutSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @State private var about: [String: JSONValue]?
    @State private var copied = false

    private static let repo = URL(string: "https://github.com/elabx-org/fusionha")!

    private static let attributions: [(name: String, site: String, url: String, text: String, note: String)] = [
        ("The Movie Database", "themoviedb.org", "https://www.themoviedb.org",
         "Movie & series metadata, artwork, cast and ratings.",
         "This product uses the TMDB API but is not endorsed or certified by TMDB."),
        ("TheTVDB", "thetvdb.com", "https://thetvdb.com",
         "Alternate series numbering & series missing from TMDB.",
         "Metadata provided by TheTVDB. Please consider adding missing information or subscribing."),
        ("TVmaze", "tvmaze.com", "https://www.tvmaze.com",
         "Episode air dates & times.", "Data licensed under CC BY-SA."),
        ("Sonarr", "sonarr.tv", "https://sonarr.tv",
         "fusionha is deeply inspired by Sonarr. Its series management, quality profiles and upgrade semantics shaped this app, and fusionha emulates the Sonarr v3 API.",
         "Open source (GPL-3.0) — not affiliated."),
        ("Radarr", "radarr.video", "https://radarr.video",
         "fusionha is deeply inspired by Radarr. Its movie management and custom-format engine are the blueprint fusionha follows, and fusionha emulates the Radarr v3 API.",
         "Open source (GPL-3.0) — not affiliated."),
        ("TRaSH Guides", "trash-guides.info", "https://trash-guides.info",
         "Custom formats, quality profiles and size definitions imported from the community guides.", "CC BY-SA 4.0."),
        ("FFmpeg / ffprobe", "ffmpeg.org", "https://ffmpeg.org",
         "Media analysis & file verification on import.", "LGPL/GPL — bundled binary, source available."),
    ]

    var body: some View {
        SettingsForm(slug: "about") {
            Section {
                hero
                    .settingsReveal(delay: 0.04)
                strip
                    .settingsReveal(delay: 0.1)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            SettingsSection("Data & metadata attributions") {
                ForEach(Array(Self.attributions.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                            if let url = URL(string: item.url) {
                                Link("\(item.site) ↗", destination: url)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.i2)
                            }
                        }
                        Text(item.text).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        Text(item.note).font(.system(size: 12).italic()).foregroundStyle(Theme.dim)
                    }
                    .padding(.vertical, 3)
                    .settingsReveal(delay: 0.06 * Double(index))
                }
            }

            SettingsSection("Project") {
                Link(destination: Self.repo) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                Link(destination: Self.repo.appendingPathComponent("issues")) { Label("Report an issue", systemImage: "exclamationmark.circle") }
                if let server = store.client?.baseURL {
                    Link(destination: server.appendingPathComponent("docs")) { Label("Documentation", systemImage: "book.closed") }
                }
                Link(destination: Self.repo.appendingPathComponent("releases")) { Label("Changelog", systemImage: "arrow.down.to.line") }
            }
            .settingsField("Project links")
            .tint(Theme.txt)

            Section {
                Text("Made for self-hosters, standing on the shoulders of **Sonarr** & **Radarr**. **fusionha** is open source — GPL-3.0.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .task {
            about = try? await store.client?.json("GET", "/api/v1/system/about").object
        }
    }

    private var version: String? { about?["version"]?.string }

    private var hero: some View {
        HStack(spacing: 14) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .monochromeWash()
                .frame(width: 54, height: 54)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.line))
            VStack(alignment: .leading, spacing: 2) {
                Text("fusionha").font(.system(size: 21, weight: .bold)).tracking(-0.4).foregroundStyle(Theme.txt)
                Text("Movies, series & anime — one library, every version.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                HStack(spacing: 8) {
                    Text(version.map { "v\($0)" } ?? "—")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.i2)
                    HStack(spacing: 6) {
                        Circle().fill(Theme.done).frame(width: 6, height: 6)
                        Text("Up to date")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.done)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.done.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.done.opacity(0.35)))
                    Button { copyInfo() } label: {
                        HStack(spacing: 4) {
                            Text(copied ? "copied" : "copy info")
                            if copied { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.line))
                    }
                    .buttonStyle(.plain)
                    .disabled(about == nil)
                    .settingsField("Copy info")
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Theme.panel)
        .overlay(alignment: .topTrailing) {
            RadialGradient(colors: [Theme.indigo.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
    }

    private var strip: some View {
        let cells: [(String, String)] = [
            ("Build", about.map { "\($0["commit"]?.string ?? "dev") · \($0["build_date"]?.string ?? "—")" } ?? "—"),
            ("Runtime", about?["python"]?.string.map { "Python \($0) · FastAPI" } ?? "—"),
            ("Database", about.map { "SQLite · schema \($0["db_schema_rev"]?.string ?? "—")" } ?? "—"),
            ("Uptime", about?["uptime_seconds"]?.double.map(formatUptime) ?? "—"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)], spacing: 1) {
            ForEach(cells.indices, id: \.self) { i in
                let cell = cells[i]
                VStack(alignment: .leading, spacing: 3) {
                    Text(cell.0.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.57)
                        .foregroundStyle(Theme.dim)
                    Text(cell.1)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Theme.panel)
            }
        }
        .background(Theme.line)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
        .padding(.top, 14)
    }

    private func copyInfo() {
        guard let about else { return }
        UIPasteboard.general.string = [
            "fusionha v\(about["version"]?.string ?? "?")",
            "commit: \(about["commit"]?.string ?? "unknown")",
            "build date: \(about["build_date"]?.string ?? "unknown")",
            "runtime: Python \(about["python"]?.string ?? "?") · FastAPI",
            "db schema: \(about["db_schema_rev"]?.string ?? "unknown")",
            "uptime: \(formatUptime(about["uptime_seconds"]?.double ?? 0))",
            "iOS app: \(Bundle.main.appVersion)",
        ].joined(separator: "\n")
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            copied = false
        }
    }
}

/// The web's `formatUptime`: `2d 3h 04m`, `3h 04m` or `12m`.
func formatUptime(_ total: Double) -> String {
    let s = max(0, Int(total))
    let days = s / 86400, hours = (s % 86400) / 3600, minutes = (s % 3600) / 60
    let mm = String(format: "%02d", minutes)
    if days > 0 { return "\(days)d \(hours)h \(mm)m" }
    if hours > 0 { return "\(hours)h \(mm)m" }
    return "\(minutes)m"
}
