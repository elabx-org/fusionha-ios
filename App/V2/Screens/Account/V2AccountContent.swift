import SwiftUI
import FusionhaKit

/// What v2's Account rows do: `AccountView` owns the sheets, the lists
/// page and the reset, and hands them in.
struct V2AccountHooks {
    let openLists: () -> Void
    let openMethods: () -> Void
    let openSessions: () -> Void
    let reset: () -> Void
    let signOut: () -> Void
}

/// v2's one Account sheet (mock requests.js `acctGroups`, plan S12): v1's
/// avatar hub and Account & security merged, in the mock's order. Who you
/// are, then Automatic requests and requests made, Signing in, This iPhone
/// (notifications, the Live Activity as an inline toggle, widgets, colours,
/// open on), the app (Settings, web app, documentation, reset), Sign out,
/// and the version footer.
struct V2AccountContent: View {
    let me: Me
    let requestCount: Int?
    let watchlists: WatchlistsStore
    let resetting: Bool
    let signingOut: Bool
    let hooks: V2AccountHooks
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStartTab.key) private var openOn = AppStartTab.library.rawValue
    @AppStorage(LiveActivityPrefs.enabledKey) private var liveActivity = true
    @AppStorage(TitleLook.posterKey) private var posterLook = false
    @AppStorage(TabsLook.collapsedKey) private var collapsedTabs = false
    @AppStorage(TabsLook.confirmedKey) private var collapsedTabsKept = false
    @AppStorage(TabsLook.bottomKey) private var tabsArrowAtBottom = false

    var body: some View {
        V2AccountHead(me: me, server: model.credentials?.serverURL)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

        Section {
            if me.hasCapability("request") {
                Button(action: hooks.openLists) {
                    V2AccountRow(icon: "sparkles", tint: Theme.i1, title: AutomaticRequestsCopy.rowTitle,
                                 subtitle: automaticLine, attention: watchlists.summary?.needsReview ?? 0)
                }
            }
            V2AccountRow(icon: "tray.full.fill", tint: Theme.dim, title: "Requests made",
                         value: requestCount.map(String.init) ?? "—", accessory: .none)
        }
        .listRowBackground(AccountStyle.cell)

        Section("Signing in") {
            Button(action: hooks.openMethods) {
                V2AccountRow(icon: "lock.fill", tint: Theme.dim, title: "Sign-in methods",
                             subtitle: SignInMethodsLine.text(me.credentials, plexUsername: me.plexUsername))
            }
            Button(action: hooks.openSessions) {
                V2AccountRow(icon: "globe", tint: Theme.dim, title: "Active sessions")
            }
        }
        .listRowBackground(AccountStyle.cell)

        Section(UIDevice.current.userInterfaceIdiom == .pad ? "This iPad" : "This iPhone") {
            thisDevice
        }
        .listRowBackground(AccountStyle.cell)

        Section { app } footer: { V2AccountVersionFooter() }
            .listRowBackground(AccountStyle.cell)

        Section {
            Button("Sign out", role: .destructive, action: hooks.signOut)
                .disabled(signingOut)
                .frame(maxWidth: .infinity)
        }
        .listRowBackground(AccountStyle.cell)

        V2AccountFooter()
    }

    @ViewBuilder
    private var thisDevice: some View {
        NavigationLink {
            if model.requestScoped {
                RequesterNotificationsPage()
            } else {
                NotificationsPrefsView { leave(.settings("notifications")) }
            }
        } label: {
            V2AccountRow(icon: "bell.fill", tint: Theme.danger, title: "Notifications",
                         subtitle: model.requestScoped ? "Your requests and reports" : "Approvals, held downloads, failures",
                         accessory: .none)
        }
        Toggle(isOn: $liveActivity) {
            V2AccountRow(icon: "iphone.radiowaves.left.and.right", tint: Theme.grab,
                         title: "Live Activity for downloads", accessory: .none)
        }
        .tint(Theme.primary)
        .onChange(of: liveActivity) { _, on in if !on { LiveActivityController.endAll() } }
        if liveActivity {
            NavigationLink {
                LiveActivityPrefsView()
            } label: {
                V2AccountRow(icon: "slider.horizontal.3", tint: Theme.dim, title: "Live Activity options",
                             subtitle: "Which downloads count, and how long “All done” stays", accessory: .none)
            }
        }
        Button { leave(.widgets) } label: {
            V2AccountRow(icon: "square.grid.2x2.fill", tint: Theme.edition, title: "Widgets",
                         subtitle: "What the Home Screen widgets last did")
        }
        NavigationLink {
            AccountColoursPage()
        } label: {
            V2AccountRow(icon: "circle.lefthalf.filled", tint: Theme.i1, title: "App colours",
                         value: PaletteStore.shared.active.name, accessory: .none)
        }
        Toggle(isOn: $posterLook) {
            V2AccountRow(icon: "rectangle.portrait.inset.filled", tint: Theme.i1, title: "Poster title page",
                         subtitle: "Try the new title page. Off is today's.", accessory: .none)
        }
        .tint(Theme.primary)
        Toggle(isOn: $collapsedTabs) {
            V2AccountRow(icon: "chevron.down.circle.fill", tint: Theme.i1, title: "Collapsed tabs",
                         subtitle: "iPhone Duo: the tabs open from an arrow, top right. Search uses the full width.",
                         accessory: .none)
        }
        .tint(Theme.primary)
        // Turned on again: ask once more whether to keep it (`CollapsedTabsConfirm`).
        .onChange(of: collapsedTabs) { _, on in if on { collapsedTabsKept = false } }
        if collapsedTabs {
            Picker(selection: $tabsArrowAtBottom) {
                Text("Top").tag(false)
                Text("Bottom").tag(true)
            } label: {
                V2AccountRow(icon: "arrow.up.and.down.circle.fill", tint: Theme.dim, title: "Tabs arrow",
                             subtitle: "Where it sits in the side column", accessory: .none)
            }
            .tint(Theme.mut)
        }
        Picker(selection: $openOn) {
            ForEach(AppStartTab.allCases) { Text($0.label).tag($0.rawValue) }
        } label: {
            V2AccountRow(icon: "rectangle.portrait.on.rectangle.portrait", tint: Theme.dim, title: "Open on",
                         accessory: .none)
        }
        .pickerStyle(.navigationLink)
    }

    @ViewBuilder
    private var app: some View {
        if model.credentials != nil, !model.requestScoped {
            Button { leave(.settings(nil)) } label: {
                V2AccountRow(icon: "gearshape.fill", tint: Theme.dim, title: "Settings")
            }
        }
        if let server = model.credentials?.serverURL {
            Button { openURL(server) } label: {
                V2AccountRow(icon: "safari", tint: Theme.dim, title: "Open the web app", accessory: .external)
            }
            Button { openURL(server.appendingPathComponent("docs")) } label: {
                V2AccountRow(icon: "book.closed.fill", tint: Theme.dim, title: "Documentation", accessory: .external)
            }
        }
        Button(action: hooks.reset) {
            V2AccountRow(icon: "arrow.clockwise", tint: Theme.dim, title: resetting ? "Resetting…" : "Reset cache",
                         subtitle: "Reloads what’s on screen; you stay signed in", accessory: .none)
        }
        .disabled(resetting)
    }

    private var automaticLine: String {
        guard let summary = watchlists.summary else {
            return watchlists.summaryFailed ? AutomaticRequestsCopy.rowFailed : AutomaticRequestsCopy.loading
        }
        let line = AutomaticRequestsCopy.rowLine(summary)
        return line.review.map { line.text + " · " + $0 } ?? line.text
    }

    /// Leaves Account for a full-screen page: from the sheet, once it has
    /// closed (the shell's onDismiss opens it); from the You tab, at once.
    private func leave(_ destination: AccountHubSheet.Destination) {
        model.avatar.pending = destination
        if model.showingAccount { model.showingAccount = false } else { model.avatar.openPending(model) }
    }
}
