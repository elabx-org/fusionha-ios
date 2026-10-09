import SwiftUI
import FusionhaKit

// MARK: Add / edit

private enum ClientType: String, Identifiable {
    case sab, qbit
    var id: String { rawValue }
    var label: String { self == .sab ? "SABnzbd" : "qBittorrent" }
    var wireProtocol: String { self == .sab ? "USENET" : "TORRENT" }
    var sub: String {
        self == .sab ? "usenet · SAB-compatible APIs supported"
            : "torrent · qBit-compatible APIs (decypharr, rdt-client)"
    }
    var defaultPort: String { self == .sab ? "8282" : "8080" }
    var defaultUrlBase: String { self == .sab ? "sabnzbd" : "" }
}

/// SABnzbd queue priorities (backend `_validate_sab_priority`).
private let sabPriorities: [(Int, String)] = [
    (-100, "Default"), (-2, "Paused"), (-1, "Low"), (0, "Normal"), (1, "High"), (2, "Force"),
]

/// Client priority: ordering across clients of the same protocol.
private let clientPriorities: [(Int, String)] = [
    (1, "1 — first choice"), (2, "2"), (3, "3"), (4, "4"), (5, "5 — last resort"),
]

/// The two-step dialog: adding starts on the type picker; editing opens the form.
struct DownloadClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsMotionOff) private var motionOff
    let client: DownloadClientInfo?
    let onSaved: () async -> Void
    @State private var type: ClientType?

    init(client: DownloadClientInfo?, onSaved: @escaping () async -> Void) {
        self.client = client
        self.onSaved = onSaved
        _type = State(initialValue: client.map { $0.isTorrent ? .qbit : .sab })
    }

    var body: some View {
        ZStack {
            if let type {
                DownloadClientForm(type: type, client: client,
                                   onBack: client == nil ? { setType(nil) } : nil,
                                   onSaved: onSaved)
                    .transition(motionOff ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)),
                                                                   removal: .opacity.combined(with: .offset(y: -8))))
            } else {
                picker
                    .transition(motionOff ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)),
                                                                   removal: .opacity.combined(with: .offset(y: -8))))
            }
        }
    }

    private func setType(_ new: ClientType?) {
        SettingsMotion.perform(motionOff, SettingsMotion.reveal(0.3)) { type = new }
    }

    private var picker: some View {
        NavigationStack {
            Form {
                Section {
                    pickCard(.sab, badge: "SAB", tint: Theme.miss,
                             description: "The free usenet downloader. Also works with SAB-compatible APIs (decypharr, nzbget-sab shims).",
                             proto: "usenet")
                } header: { pickHeader("Usenet") }
                .listRowBackground(Theme.card)
                Section {
                    pickCard(.qbit, badge: "qB", tint: Theme.unaired,
                             description: "Also works with qBit-compatible APIs (decypharr, rdt-client for Real-Debrid).",
                             proto: "torrent")
                } header: { pickHeader("Torrent / Debrid") }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Download Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
            }
            .safeAreaInset(edge: .top) {
                Text("Pick a client type").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 4)
            }
        }
        .tint(Theme.cyan)
    }

    private func pickHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .heavy)).tracking(0.6).foregroundStyle(Theme.dim)
    }

    private func pickCard(_ t: ClientType, badge: String, tint: Color, description: String, proto: String) -> some View {
        Button { setType(t) } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(badge)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.label).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(description).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(proto)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.4)))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.dim)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Step 2: the full config form + Test / Save.
private struct DownloadClientForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let type: ClientType
    let client: DownloadClientInfo?
    let onBack: (() -> Void)?
    let onSaved: () async -> Void

    @State private var name: String
    @State private var enable: Bool
    @State private var host: String
    @State private var port: String
    @State private var useSsl: Bool
    @State private var urlBase: String
    @State private var username: String
    @State private var password = ""
    @State private var catMovie: String
    @State private var catSeries: String
    @State private var catAnime: String
    @State private var recentPriority: Int
    @State private var olderPriority: Int
    @State private var removeCompleted: Bool
    @State private var removeFailed: Bool
    @State private var priority: Int
    @State private var postImportCategory: String
    @State private var advancedOpen = false
    @State private var result: ConnectionTestResult?
    @State private var testing = false
    @State private var saving = false
    @State private var saveError: String?

    init(type: ClientType, client: DownloadClientInfo?, onBack: (() -> Void)?, onSaved: @escaping () async -> Void) {
        self.type = type
        self.client = client
        self.onBack = onBack
        self.onSaved = onSaved
        let cat: (String, String) -> String = { key, fallback in
            client.map { $0.categoryMap?[key] ?? "" } ?? fallback
        }
        _name = State(initialValue: client?.name ?? type.label)
        _enable = State(initialValue: client?.enable ?? true)
        _host = State(initialValue: client?.host ?? "")
        _port = State(initialValue: client.map { String($0.port) } ?? type.defaultPort)
        _useSsl = State(initialValue: client?.useSsl ?? false)
        _urlBase = State(initialValue: client?.urlBase ?? type.defaultUrlBase)
        _username = State(initialValue: client?.username ?? "")
        _catMovie = State(initialValue: cat("movie", "movies"))
        _catSeries = State(initialValue: cat("series", "tv"))
        _catAnime = State(initialValue: cat("anime", "anime"))
        _recentPriority = State(initialValue: client?.recentPriority ?? -100)
        _olderPriority = State(initialValue: client?.olderPriority ?? -100)
        _removeCompleted = State(initialValue: client?.removeCompleted ?? true)
        _removeFailed = State(initialValue: client?.removeFailed ?? true)
        _priority = State(initialValue: client?.priority ?? 1)
        _postImportCategory = State(initialValue: client?.postImportCategory ?? "")
    }

    private func t(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces) }
    private var valid: Bool { !t(name).isEmpty && !t(host).isEmpty && Int(t(port)) != nil }
    private var title: String { client == nil ? "Add \(type.label)" : "Edit \(type.label)" }

    var body: some View {
        FetchFormSheet(title: title, subtitle: type.sub, saveLabel: "Save client",
                       canSave: valid && !testing, saving: saving,
                       onCancel: { dismiss() }, onSave: save) {
            SettingsSection("Client") {
                FetchTextRow(label: "Name", text: $name)
                FetchToggleRow(label: "Enabled", description: "Disabled clients are kept but never used", isOn: $enable)
            }
            SettingsSection("Connection") {
                FetchTextRow(label: "Host", text: $host, prompt: "192.168.1.10", mono: true, keyboard: .URL)
                FetchTextRow(label: "Port", text: $port, mono: true, keyboard: .numberPad)
                FetchToggleRow(label: "SSL", isOn: $useSsl)
                FetchTextRow(label: "URL Base", text: $urlBase, prompt: "e.g. sabnzbd", mono: true,
                             hint: "The fix: the prefix before /api, when the client sits behind one.")
                if type == .sab {
                    FetchTextRow(label: "API Key", text: $password,
                                 prompt: client?.passwordConfigured == true ? "•••• (unchanged)" : "", secure: true, mono: true)
                } else {
                    FetchTextRow(label: "Username", text: $username, mono: true)
                    FetchTextRow(label: "Password", text: $password,
                                 prompt: client?.passwordConfigured == true ? "•••• (unchanged)" : "", secure: true, mono: true)
                }
            }
            SettingsSection("Categories — one per media type") {
                categoryRow("Movies", "film", $catMovie)
                categoryRow("Series", "tv", $catSeries)
                categoryRow("Anime", "sparkles", $catAnime)
            }
            if type == .sab {
                SettingsSection("Priorities") {
                    priorityPicker("Recent Priority", "aired < 14 days", $recentPriority)
                    priorityPicker("Older Priority", nil, $olderPriority)
                }
            }
            SettingsSection("Completed & failed handling") {
                FetchToggleRow(label: "Remove completed",
                               description: "Remove from the client’s history after fusionha imports it", isOn: $removeCompleted)
                FetchToggleRow(label: "Remove failed",
                               description: "Remove failed downloads from the client’s history", isOn: $removeFailed)
            }
            Section {
                DisclosureGroup(isExpanded: $advancedOpen) {
                    Picker(selection: $priority) {
                        ForEach(clientPriorities, id: \.0) { Text($0.1).tag($0.0) }
                    } label: { FieldLabel(label: "Client priority") }
                    .pickerStyle(.menu).tint(Theme.mut)
                    if type == .qbit {
                        FetchTextRow(label: "Post-import category", text: $postImportCategory,
                                     prompt: "leave blank to keep category", mono: true)
                    }
                } label: {
                    Text("Advanced").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                }
            }
            .listRowBackground(Theme.card)
            Section {
                HStack(spacing: 10) {
                    Button { runTest() } label: { Label("Test", systemImage: "bolt.fill") }
                        .buttonStyle(.web())
                        .disabled(!valid || testing || saving)
                    FetchTestResultLine(testing: testing, result: result, clientLabel: type.label)
                    Spacer(minLength: 0)
                }
                if let saveError {
                    Label(saveError, systemImage: "xmark").font(.system(size: 12)).foregroundStyle(Theme.danger)
                }
                if let onBack {
                    Button("‹ Back") { onBack() }.buttonStyle(.web(.ghost))
                }
            }
            .listRowBackground(Theme.card)
        }
    }

    private func categoryRow(_ label: String, _ icon: String, _ text: Binding<String>) -> some View {
        LabeledContent {
            TextField(label, text: text)
                .font(.system(size: 14, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } label: {
            Label(label, systemImage: icon).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
        }
    }

    private func priorityPicker(_ label: String, _ hint: String?, _ value: Binding<Int>) -> some View {
        Picker(selection: value) {
            ForEach(sabPriorities, id: \.0) { Text($0.1).tag($0.0) }
        } label: {
            FieldLabel(label: label, description: hint.map { "— \($0)" })
        }
        .pickerStyle(.menu)
        .tint(Theme.mut)
    }

    /// The full create body, shared by the unsaved test and create/update.
    private func payload() -> SettingsJSON {
        var categories: [String: SettingsJSON] = [:]
        if !t(catMovie).isEmpty { categories["movie"] = .string(t(catMovie)) }
        if !t(catSeries).isEmpty { categories["series"] = .string(t(catSeries)) }
        if !t(catAnime).isEmpty { categories["anime"] = .string(t(catAnime)) }
        var b: [String: SettingsJSON] = [
            "name": .string(t(name)),
            "protocol": .string(type.wireProtocol),
            "host": .string(t(host)),
            "port": .int(Int(t(port)) ?? 0),
            "use_ssl": .bool(useSsl),
            "url_base": t(urlBase).isEmpty ? .null : .string(t(urlBase)),
            "username": type == .qbit && !t(username).isEmpty ? .string(t(username)) : .null,
            "enable": .bool(enable),
            "priority": .int(priority),
            "recent_priority": .int(type == .sab ? recentPriority : -100),
            "older_priority": .int(type == .sab ? olderPriority : -100),
            "remove_completed": .bool(removeCompleted),
            "remove_failed": .bool(removeFailed),
            "post_import_category": type == .qbit && !t(postImportCategory).isEmpty ? .string(t(postImportCategory)) : .null,
            "category_map": .object(categories),
        ]
        // path_map is left as stored on edit (it is not part of this form).
        if client == nil { b["path_map"] = .object([:]) }
        if !password.isEmpty { b["password"] = .string(password) }
        return .object(b)
    }

    private func runTest() {
        guard let api = model.client, valid else { return }
        result = nil
        testing = true
        Task {
            do {
                result = try await api.configTestUnsaved(.downloadClients, payload())
            } catch {
                result = ConnectionTestResult(ok: false, message: error.settingsMessage)
            }
            testing = false
        }
    }

    private func save() {
        guard let api = model.client, valid else { return }
        saving = true
        saveError = nil
        Task {
            do {
                if let client {
                    try await api.configUpdate(.downloadClients, id: client.id, payload())
                } else {
                    try await api.configCreate(.downloadClients, payload())
                }
                await onSaved()
                dismiss()
            } catch {
                saveError = error.settingsMessage
            }
            saving = false
        }
    }
}
