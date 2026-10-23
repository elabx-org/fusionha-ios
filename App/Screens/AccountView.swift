import SwiftUI
import WidgetKit
import FusionhaKit

/// The web's Account panel (`AccountPanel` + `AccountContent`): the
/// role-tinted avatar, the display name and role badge, then Requests made ·
/// Sign-in methods · Active sessions · Reset cache & reload · Automatic
/// requests · Notifications · Sign out. The Account sheet and the requester's
/// You tab both show it. Automatic requests is one row (fusionha 0.4.226) that
/// pushes Watchlists & lists.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var requestCount: Int?
    @State private var showingMethods = false
    @State private var showingSessions = false
    @State private var resetting = false
    @State private var signingOut = false
    @State private var watchlists = WatchlistsStore()
    @State private var showingLists = false
    @State private var listsSource: String?

    var body: some View {
        List {
            if let me = model.me {
                content(me)
            } else {
                Text("Loading account…")
                    .foregroundStyle(Theme.mut)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .tint(Theme.i2)
        .refreshable {
            await loadRequests()
            await watchlists.load(model.client)
        }
        .task { await loadRequests() }
        .automaticRequestsLoading(watchlists, client: model.client)
        .navigationDestination(isPresented: $showingLists) {
            WatchlistsPage(store: watchlists, initialSource: listsSource)
        }
        // `fusionha://account/lists[/<source-id>]` and `account#watchlist`.
        .onChange(of: model.pendingLists, initial: true) {
            guard let link = model.pendingLists else { return }
            model.pendingLists = nil
            openLists(link.sourceId)
        }
        .sheet(isPresented: $showingMethods) {
            SignInMethodsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .sheet(isPresented: $showingSessions) { AccountSessionsSheet() }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACCOUNT"] == "methods" {
                try? await Task.sleep(for: .seconds(1.5))
                showingMethods = true
            }
            // Watchlists & lists, and a source on it (`FUSIONHA_SCREENSHOT_LISTS_SOURCE`).
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ACCOUNT"] == "lists" {
                try? await Task.sleep(for: .seconds(1))
                openLists(ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_LISTS_SOURCE"])
            }
            #endif
        }
    }

    @ViewBuilder
    private func content(_ me: Me) -> some View {
        AccountProfileHeader(me: me)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

        Section {
            HStack {
                Text("Requests made").foregroundStyle(Theme.txt)
                Spacer()
                Text("\(requestCount ?? 0)").fontWeight(.semibold).monospacedDigit().foregroundStyle(Theme.dim)
            }
            .accessibilityElement(children: .combine)
            rowButton("Sign-in methods") { showingMethods = true }
            rowButton("Active sessions") { showingSessions = true }
            rowButton(resetting ? "Resetting…" : "Reset cache & reload") { Task { await resetCache() } }
                .disabled(resetting)
        }
        .listRowBackground(AccountStyle.cell)

        if me.hasCapability("request") {
            AccountSectionHeading(AutomaticRequestsCopy.rowTitle)
            AutomaticRequestsRow(store: watchlists) { openLists(nil) }
        }

        AccountSectionHeading("Notifications")
        if model.requestScoped {
            RequesterNotificationsSection(showsTitle: false) { message, ok in
                model.toast(message, variant: ok ? .success : .error)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        } else {
            Section {
                // One home for the full matrix: Settings › Notifications.
                rowButton("Notifications settings", chevron: true) {
                    // From the Account sheet, Settings opens once the sheet has closed.
                    model.avatar.pending = .settings("notifications")
                    if model.showingAccount { model.showingAccount = false } else { model.avatar.openPending(model) }
                }
            }
            .listRowBackground(AccountStyle.cell)
        }

        Section {
            Button("Sign out") {
                signingOut = true
                Task { await model.logOut() }
            }
            .buttonStyle(CalButtonStyle(variant: .danger, fullWidth: true))
            .disabled(signingOut)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private func rowButton(_ title: String, chevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer(minLength: 8)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AccountRowButtonStyle())
    }

    // MARK: Watchlists & lists

    /// Pushes Watchlists & lists, opening `sourceId` when a link named one.
    private func openLists(_ sourceId: String?) {
        listsSource = sourceId
        showingLists = true
    }

    // MARK: Actions

    private func loadRequests() async {
        guard let client = model.client else { return }
        if let list = try? await client.requests() { requestCount = list.count }
    }

    /// The iOS form of the web's `resetAppCache`: drop cached responses and artwork
    /// and reload what's on screen. The sign-in and preferences stay.
    private func resetCache() async {
        resetting = true
        URLCache.shared.removeAllCachedResponses()
        await model.loadMe()
        if !model.requestScoped {
            await model.loadLibrary()
            await model.refreshQueue()
        }
        await loadRequests()
        await watchlists.load(model.client)
        WidgetCenter.shared.reloadAllTimelines()
        resetting = false
        model.toast("Cache cleared and reloaded.")
    }
}

/// The Account sheet the avatar's hub opens on the shell (RootView hook).
struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// On both pages of the open Duo (a Spread): Account keeps to the left
    /// page; Watchlists & lists, pushed, splits itself at the fold.
    var onPages = false

    var body: some View {
        NavigationStack {
            AccountView()
                .foldLeadingColumn(onPages)
                .background(Theme.bg.ignoresSafeArea())
                .navigationTitle("Account")
                // Across both pages the title keeps to the left page, off the fold.
                .toolbarTitleDisplayMode(onPages ? .inlineLarge : .inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        SheetDoneButton { dismiss() }
                    }
                }
                .closeOnlyBars()
        }
        // Sheets hide the shell's toasts.
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, 24) }
        // Unfolded: a form sheet, near the web's ~520 panel (DC19). Centred,
        // not trailing: see the D4 notes in the parity audit.
        .formSheet(!onPages)
    }
}

private struct AccountRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.i2 : Theme.txt)
    }
}
