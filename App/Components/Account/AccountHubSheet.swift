import SwiftUI
import FusionhaKit

/// The account sheet (approved mock "Account sheet redesign"): who you are and
/// whether the server is healthy, then This iPhone (colours, Live Activity,
/// notifications, widgets, start tab), then the server, then reset and log
/// out. iOS 26 sheet glass at half height, so it has no background of its
/// own; rows sit on solid cells. Long-press the version for diagnostics.
struct AccountHubSheet: View {
    enum Destination { case settings(String?), account, widgets }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStartTab.key) private var openOn = AppStartTab.library.rawValue
    @AppStorage(LiveActivityPrefs.enabledKey) private var liveActivity = true
    let diagnostics: String
    /// Runs once the sheet has closed (full-screen Settings, Account, Widgets).
    let open: (Destination) -> Void
    @State private var showingDiagnostics = false
    @State private var flash = SettingsFlash()

    var body: some View {
        NavigationStack {
            List {
                AccountHeader(me: model.me, server: model.credentials?.serverURL, queued: model.queue.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                Section("This iPhone") {
                    NavigationLink {
                        AccountColoursPage()
                    } label: {
                        AccountRow(icon: "circle.lefthalf.filled", tint: Theme.i1, title: "App colours",
                                   value: PaletteStore.shared.active.name)
                    }
                    NavigationLink {
                        LiveActivityPrefsView()
                    } label: {
                        AccountRow(icon: "iphone.radiowaves.left.and.right", tint: Theme.grab, title: "Live Activity",
                                   value: liveActivity ? "On" : "Off")
                    }
                    NavigationLink {
                        NotificationsPrefsView { close(then: .settings("notifications")) }
                    } label: {
                        AccountRow(icon: "bell.fill", tint: Theme.danger, title: "Notifications")
                    }
                    Button { close(then: .widgets) } label: {
                        AccountRow(icon: "square.grid.2x2.fill", tint: Theme.edition, title: "Widgets", chevron: true)
                    }
                    Picker(selection: $openOn) {
                        ForEach(AppStartTab.allCases) { Text($0.label).tag($0.rawValue) }
                    } label: {
                        AccountRow(icon: "rectangle.portrait.on.rectangle.portrait", tint: Theme.dim, title: "Open on")
                    }
                    .pickerStyle(.navigationLink)
                }
                .listRowBackground(AccountStyle.cell)

                Section("fusionha server") {
                    if model.credentials != nil, !model.requestScoped {
                        Button { close(then: .settings(nil)) } label: {
                            AccountRow(icon: "slider.horizontal.3", tint: Theme.dim, title: "Settings", chevron: true)
                        }
                    }
                    Button { close(then: .account) } label: {
                        AccountRow(icon: "person.crop.circle", tint: Theme.dim, title: "Account & security", chevron: true)
                    }
                    if let server = model.credentials?.serverURL {
                        Button { openURL(server.appendingPathComponent("docs")) } label: {
                            AccountRow(icon: "book.closed", tint: Theme.dim, title: "Documentation", external: true)
                        }
                        Button { openURL(server) } label: {
                            AccountRow(icon: "safari", tint: Theme.dim, title: "Open web app", external: true)
                        }
                    }
                }
                .listRowBackground(AccountStyle.cell)

                Section {
                    Button("Reset cache & reload") {
                        dismiss()
                        Task { await model.resetCacheAndReload() }
                    }
                    .foregroundStyle(Theme.i2)
                    Button("Log out", role: .destructive) {
                        dismiss()
                        Task { await model.logOut() }
                    }
                } footer: {
                    versionFooter
                }
                .listRowBackground(AccountStyle.cell)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(Theme.i2)
        .environment(flash)
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("fusionha for iOS \(Bundle.main.appVersion)")
            if showingDiagnostics, !diagnostics.isEmpty {
                Text(diagnostics).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.dim)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onLongPressGesture { withAnimation(.snappy) { showingDiagnostics.toggle() } }
        .accessibilityHint("Touch and hold for diagnostics")
    }

    private func close(then destination: Destination) {
        dismiss()
        open(destination)
    }
}

/// Account › App colours: the same rows as Settings › Appearance › Theme.
private struct AccountColoursPage: View {
    var body: some View {
        Form { AppPaletteSection() }
            .scrollContentBackground(.hidden)
            .navigationTitle("App colours")
            .navigationBarTitleDisplayMode(.inline)
    }
}
