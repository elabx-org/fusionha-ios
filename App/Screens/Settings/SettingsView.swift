import SwiftUI
import FusionhaKit

/// Settings (`/settings` on the web), presented over the app from the avatar
/// menu. The web's mobile layout is an iOS-style push: a master list (search,
/// General + Metadata, three expandable groups, the collapsible FETCHING and
/// SYSTEM sections) and one full-screen page per panel. Panels are routed by
/// slug through `settingsPanel(_:)`.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store: SettingsStore
    @State private var flash = SettingsFlash()
    @State private var path: [String]
    @State private var query = ""
    /// Groups and sections, all open by default (the web's `openGroups`).
    @State private var closed: Set<String> = []

    init(client: APIClient?, initialPanel: String? = nil) {
        _store = State(initialValue: SettingsStore(client: client))
        _path = State(initialValue: initialPanel.map { [$0] } ?? [])
    }

    private var motionOff: Bool { reduceMotion || !store.animationsEnabled }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        masterList
                    } else {
                        SettingsSearchResults(query: query, open: open(hit:))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 64)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.bg)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search settings…")
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close settings")
                }
            }
            .navigationDestination(for: String.self) { slug in
                settingsPanel(slug)
            }
        }
        .tint(Theme.cyan)
        .environment(store)
        .environment(flash)
        .environment(\.settingsMotionOff, motionOff)
        .environment(\.settingsPush, push)
        .task { await store.load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Settings")
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.26)
                .foregroundStyle(Theme.txt)
            Text("DB-backed · effective without restart")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.bottom, 22)
    }

    // MARK: Master list

    private var masterList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsNav.top, id: \.self) { id in
                if let panel = SettingsNav.panel(id) { row(panel) }
            }
            ForEach(SettingsNav.groups) { group in
                groupHeader(group)
                if isOpen(group.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(group.children, id: \.self) { id in
                            if let panel = SettingsNav.panel(id) { row(panel, child: true) }
                        }
                    }
                    .padding(.leading, 11)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                    .padding(.leading, 18)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(childTransition)
                }
            }
            ForEach(SettingsNav.sections) { section in
                sectionHeader(section)
                if isOpen(section.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(section.panels, id: \.self) { id in
                            if let panel = SettingsNav.panel(id) { row(panel) }
                        }
                    }
                    .transition(childTransition)
                }
            }
        }
    }

    private var childTransition: AnyTransition {
        motionOff ? .identity : .opacity.combined(with: .move(edge: .top))
    }

    private func isOpen(_ id: String) -> Bool { !closed.contains(id) }

    private func toggle(_ id: String) {
        SettingsMotion.perform(motionOff) {
            if closed.contains(id) { closed.remove(id) } else { closed.insert(id) }
        }
    }

    private func row(_ panel: SettingsPanelInfo, child: Bool = false) -> some View {
        Button { push(panel.id) } label: {
            SettingsMasterRow(panel: panel)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .padding(.top, panel.action ? 5 : 0)
        .overlay(alignment: .top) {
            if panel.action { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }

    private func groupHeader(_ group: SettingsGroupInfo) -> some View {
        Button { toggle(group.id) } label: {
            HStack(spacing: 11) {
                Image(systemName: group.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18)
                Text(group.label)
                    .font(.system(size: 13.5, weight: .bold))
                Spacer(minLength: 0)
                SettingsChevron(open: isOpen(group.id))
            }
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityValue(isOpen(group.id) ? "Expanded" : "Collapsed")
    }

    private func sectionHeader(_ section: SettingsSectionInfo) -> some View {
        Button { toggle(section.id) } label: {
            HStack(spacing: 0) {
                Text(section.label.uppercased())
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(0.57)
                    .foregroundStyle(Theme.dim)
                Spacer(minLength: 0)
                SettingsChevron(open: isOpen(section.id))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.bottom, 3)
        .accessibilityValue(isOpen(section.id) ? "Expanded" : "Collapsed")
    }

    // MARK: Navigation

    private func push(_ slug: String) {
        if motionOff {
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) { path.append(slug) }
        } else {
            path.append(slug)
        }
    }

    private func open(hit: SettingsSearchHit) {
        query = ""
        flash.set(panel: hit.panel, label: hit.kind == .field ? hit.label : nil)
        push(hit.panel)
    }
}

/// One master-list row: 15pt icon, title (14.5/650) over a wrapping subtitle
/// (11.5 `--mut`), an optional ACTION tag and the trailing `›`.
struct SettingsMasterRow: View {
    let panel: SettingsPanelInfo

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: panel.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 1) {
                    Text(panel.label)
                        .font(.system(size: 14.5, weight: .semibold))
                        .tracking(-0.145)
                        .foregroundStyle(Theme.txt)
                    Text(panel.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.mut)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 1)
                Spacer(minLength: 0)
                if panel.action { ActionTag() }
            }
            Text("›")
                .font(.system(size: 16))
                .foregroundStyle(Theme.dim)
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The ACTION tag on Import Library.
private struct ActionTag: View {
    var body: some View {
        Text("ACTION")
            .font(.system(size: 8.5, weight: .heavy))
            .tracking(0.34)
            .foregroundStyle(Theme.cyan)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.cyan.opacity(0.4)))
            .padding(.top, 3)
    }
}

/// The `›` disclosure that turns 90° when its group opens (0.2s ease, instant
/// when motion is off).
private struct SettingsChevron: View {
    let open: Bool
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        Text("›")
            .font(.system(size: 16))
            .foregroundStyle(Theme.mut)
            .rotationEffect(.degrees(open ? 90 : 0))
            .animation(motionOff ? nil : SettingsMotion.chevron, value: open)
    }
}

/// Rows have no resting fill; pressing tints them like the web's hover.
private struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Ranked search results: SETTINGS (field hits) then PAGES.
private struct SettingsSearchResults: View {
    let query: String
    let open: (SettingsSearchHit) -> Void

    var body: some View {
        let hits = SettingsSearchHit.search(query)
        let fields = hits.filter { $0.kind == .field }
        let pages = hits.filter { $0.kind == .page }
        VStack(alignment: .leading, spacing: 2) {
            if hits.isEmpty {
                Text("No settings match “\(query.trimmingCharacters(in: .whitespaces))”.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            if !fields.isEmpty { heading("Settings", fields.count) }
            ForEach(fields) { hit in resultRow(hit) }
            if !pages.isEmpty { heading("Pages", pages.count) }
            ForEach(pages) { hit in resultRow(hit) }
        }
    }

    private func heading(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title.uppercased())
            Spacer()
            Text("\(count)")
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.55)
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 3)
    }

    private func crumb(_ hit: SettingsSearchHit) -> AttributedString {
        var text = AttributedString(hit.crumb)
        if let keyword = hit.matchedKeyword {
            var match = AttributedString(" · matches “\(keyword)”")
            match.font = .system(size: 10.5, design: .monospaced)
            match.foregroundColor = Theme.cyan
            text += match
        }
        return text
    }

    private func resultRow(_ hit: SettingsSearchHit) -> some View {
        Button { open(hit) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                Text(crumb(hit))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

#if DEBUG
/// CI screenshots: `FUSIONHA_SCREENSHOT_SETTINGS=list` opens Settings at
/// launch; any other value also pushes that panel.
enum SettingsScreenshot {
    static var target: String? { ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SETTINGS"] }
    static var openAtLaunch: Bool { target != nil }
    static var panel: String? { target.flatMap { $0 == "list" ? nil : $0 } }
}
#else
enum SettingsScreenshot {
    static let openAtLaunch = false
    static let panel: String? = nil
}
#endif
