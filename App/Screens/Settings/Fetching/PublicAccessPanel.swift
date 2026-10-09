import SwiftUI
import FusionhaKit

/// Settings → Access → Public access (`PublicAccessPanel.tsx`): the read-only
/// Demo visitor card with its power toggle, and the Configure demo sheet
/// (instance banner, enable, access method, credentials, sample-library
/// lifecycle and auto-reset). Gated on `system.admin`.
struct PublicAccessPanel: View {
    @Environment(AppModel.self) private var model
    @State private var status: DemoStatus?
    @State private var error: String?
    @State private var updating = false
    @State private var configuring = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var canAdmin: Bool {
        guard let me = model.me else { return true }
        return me.isAdmin || (me.permissions ?? []).contains("system.admin")
    }

    var body: some View {
        FetchingPage(slug: "publicaccess", toaster: toaster, confirm: $confirm, refresh: load) {
            if !canAdmin {
                FetchEmpty(text: "You do not have permission to manage public access.")
            } else {
                Text("A sample library a visitor can explore read-only, with no account of their own — no data from your real library is ever shown.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .settingsReveal()
                if let status {
                    visitorCard(status).fetchReveal(1)
                } else {
                    FetchLoading(error: error)
                }
            }
        }
        .task { if canAdmin { await load() } }
        .sheet(isPresented: $configuring) {
            DemoConfigSheet(status: $status, toaster: toaster)
        }
    }

    private func visitorCard(_ data: DemoStatus) -> some View {
        let on = data.demoMode
        let blocked = data.realLibraryPresent == true
        let sub = !on
            ? (blocked ? "Blocked — this instance has a real library" : "Not shown on the login screen")
            : (data.demoRequireCredentials ? "Signs in as “\(data.demoUsername ?? "")”" : "Open · no credentials")
        return HStack(spacing: 14) {
            Text("DV")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.mut)
                .frame(width: 40, height: 40)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                FetchFlow(spacing: 6) {
                    Text("Demo visitor").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    DemoBadge(text: "Viewer", color: Theme.mut, background: Theme.panel2, dot: true)
                    DemoBadge(text: "PUBLIC", color: Theme.indigo, background: Theme.indigo.opacity(0.15), size: 10)
                    if data.demoInstanceEnv == true {
                        DemoBadge(text: "DEDICATED", color: Theme.cyan, background: Theme.cyan.opacity(0.15), size: 10)
                    }
                    DemoBadge(text: on ? "Live" : "Off", color: on ? Theme.done : Theme.dim,
                              background: (on ? Theme.done : Theme.dim).opacity(0.14), dot: true)
                }
                Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                FetchIconButton(systemName: "slider.horizontal.3", label: "Configure demo") { configuring = true }
                FetchIconButton(systemName: "power",
                                label: blocked ? "This instance has a real library — demo mode is only for a dedicated demo instance"
                                    : (on ? "Turn demo off" : "Turn demo on"),
                                tint: on ? Theme.done : nil) { togglePower(data) }
                    .disabled(updating || (!on && blocked))
                    .symbolEffect(.bounce, value: on)
            }
        }
        .padding(15)
        .background(Theme.card.mix(with: Theme.cyan, by: 0.04), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(on ? Theme.cyan.opacity(0.35) : Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .opacity(on ? 1 : 0.72)
        .animation(.easeOut(duration: 0.16), value: on)
    }

    private func togglePower(_ data: DemoStatus) {
        if !data.demoMode && data.realLibraryPresent == true {
            toaster.show("This instance has a real library. Spin up a separate instance with FUSIONHA_DEMO_INSTANCE=1.",
                         title: "Demo mode is blocked here", tone: .error)
            return
        }
        guard let client = model.client else { return }
        updating = true
        Task {
            defer { updating = false }
            do {
                status = try await client.updateDemo(["demo_mode": .bool(!data.demoMode)])
            } catch {
                toaster.show(error.settingsMessage, title: "Could not update demo mode", tone: .error)
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            status = try await client.demoStatus()
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error.settingsMessage
        }
    }
}

/// Role / status / tag pill on the demo row.
private struct DemoBadge: View {
    let text: String
    let color: Color
    let background: Color
    var dot = false
    var size: CGFloat = 10.5

    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text).font(.system(size: size, weight: .bold)).tracking(size == 10 ? 0.3 : 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, size == 10 ? 8 : 9)
        .padding(.vertical, 2.5)
        .background(background, in: Capsule())
        .fixedSize()
    }
}

// MARK: Configure demo

private struct DemoConfigSheet: View {
    @Binding var status: DemoStatus?
    let toaster: FetchToaster
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var username = ""
    @State private var password = ""
    @State private var updating = false
    @State private var busy: String?
    @State private var confirmWipe = false

    private static let autoReset: [(hours: Int?, label: String)] = [
        (nil, "Off"), (1, "Every hour"), (6, "Every 6 hours"), (24, "Daily"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                } header: {
                    Text("A dedicated, disposable demo instance — the whole library is sample data a visitor can explore read-only. Nothing here touches a real fusionha.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut).textCase(nil)
                        .padding(.horizontal, -4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let data = status {
                    Section { banner(data) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    Section {
                        Toggle(isOn: Binding(get: { data.demoMode },
                                             set: { put(["demo_mode": .bool($0)], "Could not update demo mode") })) {
                            FieldLabel(label: "Demo enabled",
                                       description: data.realLibraryPresent == true
                                       ? "Blocked — this instance has a real library."
                                       : "Shows an “Explore the demo” entry on the login screen.")
                        }
                        .tint(Theme.indigo)
                        .disabled(updating || data.realLibraryPresent == true)
                    }

                    Section {
                        Picker("Access method", selection: Binding(
                            get: { data.demoRequireCredentials },
                            set: { put(["demo_require_credentials": .bool($0)], "Could not update the access method") })) {
                            Text("Demo login (default)").tag(true)
                            Text("Open · no credentials").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } header: {
                        Text("Access method")
                    }

                    if data.demoRequireCredentials {
                        Section {
                            FetchTextRow(label: "Demo username", text: $username)
                            FetchTextRow(label: "Demo password", text: $password,
                                         prompt: data.demoPasswordSet == true ? "•••• (unchanged)" : "Set a demo password",
                                         secure: true)
                            HStack {
                                Spacer()
                                Button("Save credentials") { saveCredentials(data) }
                                    .buttonStyle(.web(.subtle))
                                    .disabled(updating)
                            }
                        }
                        .transition(.opacity)
                    }

                    Section { sampleLibrary(data) }

                    Section {
                        Picker(selection: Binding(
                            get: { data.demoAutoResetHours },
                            set: { put(["demo_auto_reset_hours": .optional($0)], "Could not update auto-reset") })) {
                            ForEach(Self.autoReset, id: \.label) { option in
                                Text(option.label).tag(option.hours)
                            }
                        } label: {
                            FieldLabel(label: "Auto-reset",
                                       description: "Periodically wipe and rebuild the sample library so it always looks freshly alive.")
                        }
                        .pickerStyle(.menu)
                        .disabled(!data.demoSeeded || updating)
                    }
                } else {
                    Section { SettingsLoadingRow() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Configure demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton { dismiss() }
                }
            }
            .animation(motionOff ? nil : .easeOut(duration: 0.2), value: status?.demoRequireCredentials)
        }
        .tint(Theme.cyan)
        .fetchToasts(toaster)
        .presentationDragIndicator(.visible)
        .onAppear { username = status?.demoUsername ?? "" }
        .onChange(of: status?.demoUsername) { username = status?.demoUsername ?? "" }
    }

    private func banner(_ data: DemoStatus) -> some View {
        let counts = data.counts
        let (color, text): (Color, String) = {
            if data.realLibraryPresent == true {
                return (Theme.miss, "This instance has \(data.itemCount ?? 0) real item(s). Demo mode is blocked here — spin up a separate instance with FUSIONHA_DEMO_INSTANCE=1.")
            }
            if data.demoSeeded {
                return (Theme.done, "Running on sample data (\(counts?.movies ?? 0) movies · \(counts?.series ?? 0) series · \(counts?.anime ?? 0) anime).")
            }
            if data.demoInstanceEnv == true {
                return (Theme.cyan, "Dedicated demo instance — seed the sample library to fill it, then reset or wipe any time.")
            }
            return (Theme.dim, "Empty instance — seed the sample library to start the demo.")
        }()
        return Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.txt)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [color.opacity(0.16), color.opacity(0)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
            .accessibilityAddTraits(.isStaticText)
    }

    private func sampleLibrary(_ data: DemoStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(label: "Sample library",
                       description: "A curated sample library — movies, series, anime, an alive queue and a history backlog. Seed it, rebuild it fresh, or empty it.")
            if data.demoSeeded, let c = data.counts {
                FetchFlow(spacing: 6) {
                    countChip(c.movies, "movies")
                    countChip(c.series, "series")
                    countChip(c.anime, "anime")
                    countChip(c.editions, "versions")
                    countChip(c.files, "files")
                    countChip(c.downloadsActive, "in queue")
                    countChip(c.historyEvents, "history")
                }
            }
            FetchFlow(spacing: 8) {
                Button(busy == "seed" ? "Seeding…" : (data.demoSeeded ? "Re-seed" : "Seed sample library")) {
                    action("seed", "Could not seed the demo")
                }
                .buttonStyle(.web(.subtle))
                .disabled(!data.demoMode || data.realLibraryPresent == true || busy != nil)

                Button(busy == "reset" ? "Resetting…" : "Reset demo") {
                    action("reset", "Could not reset the demo")
                }
                .buttonStyle(.web(.ghost))
                .disabled(!data.demoMode || !data.demoSeeded || busy != nil)

                if confirmWipe {
                    Button(busy == "wipe" ? "Wiping…" : "Confirm wipe?") {
                        action("wipe", "Could not wipe the demo") { confirmWipe = false }
                    }
                    .buttonStyle(.web(.danger))
                    .disabled(busy != nil)
                    Button("Cancel") { confirmWipe = false }
                        .buttonStyle(.web(.ghost))
                        .disabled(busy != nil)
                } else {
                    Button("Wipe") { confirmWipe = true }
                        .buttonStyle(.web(.ghost))
                        .disabled(!data.demoMode || !data.demoSeeded || busy != nil)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func countChip(_ value: Int?, _ label: String) -> some View {
        (Text("\(value ?? 0)").fontWeight(.bold).foregroundStyle(Theme.txt) + Text(" \(label)"))
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.line))
    }

    // MARK: Actions

    private func put(_ body: SettingsJSON, _ title: String, then: (() -> Void)? = nil) {
        guard let client = model.client else { return }
        updating = true
        Task {
            defer { updating = false }
            do {
                status = try await client.updateDemo(body)
                then?()
            } catch {
                toaster.show(error.settingsMessage, title: title, tone: .error)
            }
        }
    }

    private func saveCredentials(_ data: DemoStatus) {
        var fields: [String: SettingsJSON] = [:]
        let name = username.trimmingCharacters(in: .whitespaces)
        if name != (data.demoUsername ?? "") { fields["demo_username"] = .string(name) }
        if !password.isEmpty { fields["demo_password"] = .string(password) }
        guard !fields.isEmpty else { return }
        put(.object(fields), "Could not update demo credentials") { password = "" }
    }

    private func action(_ name: String, _ title: String, then: (() -> Void)? = nil) {
        guard let client = model.client else { return }
        busy = name
        Task {
            defer { busy = nil }
            do {
                try await client.demoAction(name)
                status = try await client.demoStatus()
                then?()
            } catch {
                toaster.show(error.settingsMessage, title: title, tone: .error)
            }
        }
    }
}
