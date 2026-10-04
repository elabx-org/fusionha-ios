import SwiftUI
import FusionhaKit

/// Settings → Database (`DatabasePanel.tsx`): the resting panel — the live
/// backend's facts beside the other backend, "Why move?" and the actions. The
/// 5-step Postgres migration wizard stays on the web panel, opened in-app.
struct DatabasePanel: View {
    @Environment(AppModel.self) private var model
    @State private var info: DatabaseBackendInfo?
    @State private var error: String?
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private static let docs = URL(string: "https://github.com/elabx-org/fusionha/blob/main/docs/deploy.md")!

    var body: some View {
        FetchingPage(slug: "database", toaster: toaster, confirm: $confirm, refresh: load) {
            if let info {
                VStack(alignment: .leading, spacing: 0) {
                    if info.backend == "postgres" { postgresResting(info) } else { sqliteResting(info) }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Theme.panel, Theme.panel2], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
                .fetchReveal(0)
            } else {
                FetchLoading(error: error)
            }
        }
        .task { await load() }
    }

    // MARK: SQLite live

    @ViewBuilder
    private func sqliteResting(_ info: DatabaseBackendInfo) -> some View {
        let sqlite = info.sqlite
        BackendCard(name: "SQLite", sub: "single-file · default", tint: Theme.done, postgres: false,
                    pill: .active, rows: [
                        ("Location", sqlite?.location ?? "—"),
                        ("Size", DatabasePanel.bytes(sqlite?.sizeBytes)),
                        ("Media files", sqlite?.mediaFileCount.map { FetchFormat.grouped($0) } ?? "—"),
                        ("Journal", sqlite?.journalMode ?? "—"),
                    ])
        arrow
        BackendCard(name: "Postgres 17", sub: "MVCC · concurrent", tint: Theme.indigo, postgres: true,
                    pill: .recommended, inactive: true, rows: [
                        ("Driver", "psycopg 3"),
                        ("Concurrency", "MVCC"),
                        ("Packaging", "compose overlay"),
                        ("Status", "not configured"),
                    ])

        HStack(alignment: .top, spacing: 11) {
            Text("◆").foregroundStyle(Theme.cyan).padding(.top, 1)
            (Text("Why move? ").fontWeight(.semibold).foregroundStyle(Theme.txt)
             + Text("Under heavy polling + RSS sync + enrichment, SQLite's single writer can stall reads (")
             + Text("database is locked").font(.system(size: 13, design: .monospaced))
             + Text(", a slow ")
             + Text("/library").font(.system(size: 13, design: .monospaced))
             + Text("). Postgres (MVCC) removes that class entirely — readers never block writers. SQLite stays the default for simple installs; this is opt-in."))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous).strokeBorder(Theme.line))
        .padding(.top, 16)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if info.applicable != false {
                    NavigationLink {
                        SettingsWebPanel(slug: "database")
                    } label: {
                        Label("Migrate to Postgres", systemImage: "arrow.right")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.web(.primary))
                }
                Link(destination: Self.docs) {
                    Text("View docs").frame(minHeight: 44)
                }
                .buttonStyle(.web(.ghost))
            }
            Text("Your SQLite database is never modified or deleted.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        }
        .padding(.top, 16)
    }

    // MARK: Postgres live

    @ViewBuilder
    private func postgresResting(_ info: DatabaseBackendInfo) -> some View {
        BackendCard(name: "Postgres", sub: "MVCC · concurrent", tint: Theme.indigo, postgres: true,
                    pill: .active, rows: [
                        ("Server", info.target?.serverVersion ?? "—"),
                        ("Database", info.target?.database ?? "—"),
                        ("Driver", "psycopg 3"),
                    ])
        arrow
        BackendCard(name: "SQLite", sub: "single-file", tint: Theme.done, postgres: false,
                    pill: .retained, inactive: true, rows: [
                        ("Status", "backup"),
                        ("Rollback", "available"),
                    ])
        (Text("fusionha is running on Postgres. Your original SQLite database is kept untouched as a backup — to roll back, point ")
         + Text("FUSIONHA_DATABASE_URL").font(.system(size: 13, design: .monospaced))
         + Text(" at it again and restart."))
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)
    }

    private var arrow: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .accessibilityHidden(true)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            info = try await client.databaseBackend()
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error.settingsMessage
        }
    }

    /// The panel's `formatBytes`: 1024-based, one decimal under 100.
    static func bytes(_ value: Int?) -> String {
        guard let value else { return "—" }
        if value < 1024 { return "\(value) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var n = Double(value) / 1024
        var unit = 0
        while n >= 1024 && unit < units.count - 1 { n /= 1024; unit += 1 }
        return String(format: n >= 100 ? "%.0f %@" : "%.1f %@", n, units[unit])
    }
}

/// One backend card (`.be`): the type colour washes in from the left, a name +
/// sub line, a status pill and a mono fact list.
private struct BackendCard: View {
    enum Pill { case active, recommended, retained }

    let name: String
    let sub: String
    let tint: Color
    let postgres: Bool
    let pill: Pill
    var inactive = false
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: postgres ? "cylinder" : "cylinder.split.1x2")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                    .frame(width: 34, height: 34)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous).strokeBorder(Theme.line))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 8)
                pillView
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    GridRow {
                        Text(row.0).foregroundStyle(Theme.dim)
                        Text(row.1)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .font(.system(size: 13))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [tint.opacity(0.13), tint.opacity(0.0)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
        .opacity(inactive ? 0.72 : 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var pillView: some View {
        switch pill {
        case .active:
            Text("● Active")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.done)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Theme.done.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.done.opacity(0.3)))
        case .recommended:
            Text("Recommended")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Theme.fusion, in: Capsule())
        case .retained:
            Text("Retained")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Theme.panel2, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
        }
    }
}
