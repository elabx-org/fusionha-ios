import SwiftUI
import WebKit
import FusionhaKit

// Settings → Security, Experimental, About, Maintenance and Discover.

// MARK: Security

/// The fusionha app API key (the web's `SecurityPanel.tsx`): redacted until
/// Reveal, then Copy / Hide; Regenerate (after a confirm) shows the new key once.
struct SecuritySettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @State private var revealed: String?
    @State private var copied = false
    @State private var busy = false
    @State private var confirmRegenerate = false
    @State private var error: String?

    var body: some View {
        SettingsForm(slug: "security") {
            SettingsSection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "key.horizontal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.mut)
                            .frame(width: 34, height: 34)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text("App API key")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.txt)
                        SettingsStatusPill(text: configured ? "Configured" : "Not set", color: configured ? Theme.done : Theme.dim)
                        Spacer(minLength: 0)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("key").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        if let revealed {
                            Text(revealed)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Theme.txt)
                                .textSelection(.enabled)
                                .transition(.opacity)
                        } else {
                            MonoText("••••••••••••••••")
                        }
                    }
                    Text("Authenticate direct API calls with the `X-Api-Key` header.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mut)
                    HStack(spacing: 8) {
                        if revealed != nil {
                            Button(copied ? "Copied" : "Copy key") { copy() }
                                .buttonStyle(.web())
                                .accessibilityLabel("Copy app API key")
                            Button("Hide key") { revealed = nil }
                                .buttonStyle(.web(.ghost))
                                .accessibilityLabel("Hide app API key")
                        } else {
                            Button("Reveal key") { Task { await reveal() } }
                                .buttonStyle(.web())
                                .disabled(busy)
                                .accessibilityLabel("Reveal app API key")
                            Button("Regenerate key") { confirmRegenerate = true }
                                .buttonStyle(.web())
                                .disabled(busy)
                                .accessibilityLabel("Regenerate app API key")
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
                    }
                }
                .padding(.vertical, 6)
                .settingsReveal(delay: 0.06)
                .settingsField("App API key")
            }
        }
        .confirmationDialog("Regenerate the app API key?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate key", role: .destructive) { Task { await regenerate() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anything using the current key stops working until you give it the new one.")
        }
    }

    private var configured: Bool { store.bool("app_key_configured") }

    private func copy() {
        guard let revealed else { return }
        UIPasteboard.general.string = revealed
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    private func reveal() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            let key = try await client.revealAppApiKey()
            withAnimation(.easeOut(duration: 0.2)) { revealed = key }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func regenerate() async {
        guard let client = store.client else { return }
        busy = true
        defer { busy = false }
        do {
            revealed = try await client.regenerateAppApiKey()
            error = nil
            await store.load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A small rounded status pill (the web's `.pill`).
struct SettingsStatusPill: View {
    let text: String
    var color: Color = Theme.done

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.32)))
    }
}

// MARK: Experimental

struct ExperimentalSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        SettingsForm(slug: "experimental") {
            if !store.loaded {
                SettingsLoadingRow()
            } else {
                SettingsSection {
                    Toggle(isOn: store.boolBinding("experimental_search_improvements")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EXPERIMENTAL")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Theme.miss)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.miss.opacity(0.45)))
                            FieldLabel(label: "Smarter automatic searches",
                                       description: "Improve fusionha's automatic replacement searches: it avoids re-grabbing a release that just failed (anti-thrash), paces retries so a bad night doesn't thrash your indexers, re-searches whole season packs, and ranks results by indexer priority and recency. Experimental — turn it off any time to restore the previous behaviour.")
                        }
                    }
                    .tint(Theme.indigo)
                    .settingsField("Smarter automatic searches")
                }
                SettingsSection("Fine-tuning") {
                    SettingNumber(key: "usenet_cross_indexer_retry_budget", label: "Usenet retry budget",
                                  description: "How many different copies of the same release to try across indexers before giving that title a rest (0 = don't retry across indexers).",
                                  unit: "copies", disabled: !enabled)
                    SettingNumber(key: "usenet_title_condemn_cooldown_seconds", label: "Condemned-title cool-off",
                                  description: "How long a title that used up its retry budget stays out of the automatic search rotation before it's tried again.",
                                  unit: "seconds", disabled: !enabled)
                    SettingNumber(key: "failed_research_burst_threshold", label: "Rapid-failure guard",
                                  description: "After this many quick failures in a row, hold off on the immediate replacement search and let things settle first.",
                                  unit: "failures", disabled: !enabled)
                    SettingNumber(key: "failed_research_min_interval_seconds", label: "Retry pacing",
                                  description: "Minimum time between replacement searches for one slot once the rapid-failure guard trips (0 = no pacing).",
                                  unit: "seconds", disabled: !enabled)
                    SettingText(key: "failed_grab_cooldown_schedule_seconds", label: "Failed-grab cool-off schedule",
                                description: "Escalating per-slot cool-offs after consecutive failed grabs — a comma-separated list of seconds, e.g. 0,300,900,1800. Empty disables it.")
                        .disabled(!enabled)
                }
                .opacity(enabled ? 1 : 0.55)
                .animation(motionOff ? nil : .easeInOut(duration: 0.2), value: enabled)
            }
        }
    }

    private var enabled: Bool { store.bool("experimental_search_improvements") }
}

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
         "fusionha is deeply inspired by Sonarr — its series management, quality profiles and upgrade semantics shaped this app, and fusionha emulates the Sonarr v3 API.",
         "Open source (GPL-3.0) — not affiliated."),
        ("Radarr", "radarr.video", "https://radarr.video",
         "fusionha is deeply inspired by Radarr — its movie management and custom-format engine are the blueprint fusionha follows, and fusionha emulates the Radarr v3 API.",
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
                                    .foregroundStyle(Theme.cyan)
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
                        .foregroundStyle(Theme.cyan)
                    HStack(spacing: 6) {
                        Circle().fill(Theme.done).frame(width: 6, height: 6)
                        Text("Up to date")
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.done)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.done.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.done.opacity(0.35)))
                    Button { copyInfo() } label: {
                        HStack(spacing: 4) {
                            Text(copied ? "copied" : "copy info")
                            if copied { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                        }
                        .font(.system(size: 10.5, design: .monospaced))
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
        .background(LinearGradient(colors: [Theme.panel, Theme.card], startPoint: .top, endPoint: .bottom))
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
                        .font(.system(size: 9.5, weight: .bold))
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

// MARK: Maintenance

/// Version, update status and the reset-cache tools. On iOS the "cache" is the
/// artwork and HTTP caches plus the in-app web panels' storage; a reset then
/// reloads the library. The full reset also clears this device's preferences
/// and signs the web panels out (the app sign-in is kept).
struct MaintenanceSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(SettingsStore.self) private var store
    @State private var serverVersion: String?
    @State private var confirmFull = false
    @State private var done: String?

    var body: some View {
        SettingsForm(slug: "maintenance") {
            SettingsSection {
                SettingValueRow(label: "Version", description: "The version of the app currently running on this device.") {
                    MonoText(Bundle.main.appVersion)
                }
                SettingValueRow(label: "Update status",
                                description: "The fusionha server this app is connected to. App updates arrive through your Feather source.") {
                    if let serverVersion {
                        SettingsStatusPill(text: "Server v\(serverVersion)")
                    } else {
                        MonoText("—")
                    }
                }
            }
            SettingsSection("Reset") {
                SettingValueRow(label: "Reset cache & reload",
                                description: "Clears the app's cached files and reloads a fresh copy. Fixes a UI that's stuck on an old version. Keeps you signed in and preserves your preferences.") {
                    Button("Reset cache & reload") { Task { await reset(full: false) } }
                        .buttonStyle(.web(.primary))
                }
                SettingValueRow(label: "Advanced: full reset",
                                description: "Everything the safe reset does, and also clears locally-stored preferences (theme, view options). Use only if a normal reset didn't help.") {
                    Button("Full reset…") { confirmFull = true }
                        .buttonStyle(.web(.danger))
                }
                if let done {
                    Label(done, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.done)
                }
            }
        }
        .alert("Full reset?", isPresented: $confirmFull) {
            Button("Cancel", role: .cancel) {}
            Button("Full reset & reload", role: .destructive) { Task { await reset(full: true) } }
        } message: {
            Text("This clears the app cache and all locally-stored preferences (theme, view options), then reloads. Your library and server settings are not affected. You may need to sign in and re-pick your preferences.")
        }
        .task {
            serverVersion = try? await store.client?.health().version
        }
    }

    private func reset(full: Bool) async {
        URLCache.shared.removeAllCachedResponses()
        var types = WKWebsiteDataStore.allWebsiteDataTypes()
        if !full { types.remove(WKWebsiteDataTypeCookies) }
        await WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast)
        if full, let bundle = Bundle.main.bundleIdentifier {
            // Device preferences only; the sign-in lives in the Keychain and App Group.
            let keep = ["serverURL", "tokenId", "authMethod"]
            let saved = keep.reduce(into: [String: Any]()) { $0[$1] = UserDefaults.standard.object(forKey: $1) }
            UserDefaults.standard.removePersistentDomain(forName: bundle)
            for (k, v) in saved { UserDefaults.standard.set(v, forKey: k) }
        }
        await store.load()
        await model.loadMe()
        await model.loadLibrary()
        withAnimation(.easeOut(duration: 0.2)) { done = full ? "Full reset done — reloaded." : "Cache cleared — reloaded." }
    }
}

// MARK: Discover

/// Ignored collections and films (the web's `IgnoredPanel.tsx`), each with
/// Un-ignore (`DELETE /api/v1/discover/ignores/{id}`).
struct DiscoverSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var rows: [JSONRecord]?
    @State private var error: String?
    @State private var busy: Set<Int> = []

    var body: some View {
        SettingsForm(slug: "discover") {
            Section {
                Text("Anything you’ve **ignored** on Discover lives here — whole collections hidden from the “Complete your collections” rail, and single films hidden within a collection. Ignoring is a reversible hide, never a delete: un-ignore to bring it straight back.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

            if let error {
                SettingsLoadingRow(error: "Couldn’t load your ignored items. Check the backend and try again. (\(error))")
            } else if let rows {
                if rows.isEmpty {
                    Section {
                        Text("Nothing ignored. Ignore a collection or a film from Discover and it’ll show up here to restore.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.mut)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                    .listRowBackground(Color.clear)
                } else {
                    let collections = rows.filter { $0["scope"]?.string == "collection" }
                    let items = rows.filter { $0["scope"]?.string == "item" }
                    group("Ignored collections", sub: "\(collections.count) hidden from the rail", collections)
                    group("Ignored films", sub: "\(items.count) hidden within a collection", items)
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
    }

    private func group(_ title: String, sub: String, _ list: [JSONRecord]) -> some View {
        Section {
            if list.isEmpty {
                Text("None.").font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
            ForEach(list) { row in
                HStack {
                    Text(label(row))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    Spacer()
                    Button("Un-ignore") { Task { await restore(row) } }
                        .buttonStyle(.web())
                        .disabled(busy.contains(row.id))
                }
                .transition(motionOff ? .identity : .opacity.combined(with: .move(edge: .trailing)))
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 12.5, weight: .bold)).textCase(.uppercase).foregroundStyle(Theme.mut)
                Spacer()
                Text(sub).font(.system(size: 11.5)).textCase(nil).foregroundStyle(Theme.dim)
            }
        }
        .listRowBackground(Theme.card)
    }

    private func label(_ row: JSONRecord) -> String {
        let name = row["name"]?.string ?? ""
        if row["scope"]?.string == "item", let collection = row["collection_name"]?.string {
            return "\(name) — in \(collection)"
        }
        return name
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            rows = try await client.records("/api/v1/discover/ignores")
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore(_ row: JSONRecord) async {
        guard let client = store.client else { return }
        busy.insert(row.id)
        defer { busy.remove(row.id) }
        do {
            try await client.json("DELETE", "/api/v1/discover/ignores/\(row.id)")
            SettingsMotion.perform(motionOff) { rows?.removeAll { $0.id == row.id } }
        } catch {
            store.saveError = "Couldn’t restore \(row["name"]?.string ?? "it") — \(error.localizedDescription)"
        }
    }
}
