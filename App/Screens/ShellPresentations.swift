import SwiftUI
import FusionhaKit

/// The shell's other sheets, deep links and polling, applied once around the
/// whole (possibly two-column) shell.
struct ShellPresentations: ViewModifier {
    @Bindable var model: AppModel
    let reduceMotion: Bool
    let scenePhase: ScenePhase
    /// The iPhone Duo is open: the Add sheet goes on the right page.
    let duoOpen: Bool
    /// Open in a Spread: Account takes both pages (Watchlists & lists splits
    /// at the fold). The Web layout keeps the usual form sheet (owner default).
    let accountOnPages: Bool
    /// The shell has been measured: Account waits for it, so a launch or a
    /// link that opens it at once doesn't show the form sheet, then the pages.
    let measured: Bool

    /// Account's form sheet (`paged` false) or its pages (`paged` true). A
    /// presentation the layout no longer picks never writes back.
    private func account(paged: Bool) -> Binding<Bool> {
        Binding(get: { measured && accountOnPages == paged && model.showingAccount },
                set: { if measured && accountOnPages == paged { model.showingAccount = $0 } })
    }

    func body(content: Content) -> some View {
        content
        // On the open Duo, the right page (S3): never a form sheet on the fold.
        .duoPageSheet(isPresented: $model.showingAdd, onPages: duoOpen) {
            AddTitleSheet()
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(Theme.panel)
        }
        .sheet(isPresented: account(paged: false),
               onDismiss: { model.avatar.openPending(model) }) {
            AccountSheet().presentationBackground(Theme.bg)
        }
        .duoPageSheet(isPresented: account(paged: true),
                      placement: .twoPages, onPages: true) {
            AccountSpreadSheet()
        }
        .onChange(of: model.showingAccount) {
            // The page cover has no onDismiss: open what the hub queued once it is gone.
            guard accountOnPages, !model.showingAccount else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                model.avatar.openPending(model)
            }
        }
        .modifier(AvatarPresentations(avatar: model.avatar, model: model))
        .modifier(SecretsLockedToaster(model: model))
        .sheet(item: $model.deleteTarget) { target in
            DeleteTitleDialog(target: target)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .onChange(of: model.pendingLink, initial: true) {
            // fusionha://activity, calendar, item/{id}… from the widgets, the
            // Live Activity and notifications (received in FusionhaApp).
            Task { await model.applyPendingLink() }
        }
        .onChange(of: model.tab) {
            model.searchText = ""
            model.chromeHidden = false
            if model.tab != .library { model.exitSelectMode() }
        }
        .task {
            #if DEBUG
            // CI screenshots: the folded iPhone Duo held sideways, when the
            // simulator cannot rotate itself (`FUSIONHA_SCREENSHOT_ORIENTATION=landscape`).
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ORIENTATION"] == "landscape",
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
            }
            #endif
            await model.loadMe()
            await model.registerPushDevice()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.pollQueue()
        }
        .task(id: "\(scenePhase == .active)|\(model.me?.id ?? -1)") {
            guard scenePhase == .active, model.me != nil else { return }
            await model.pollShell()
        }
        .task(id: "setups|\(scenePhase == .active)|\(model.me?.id ?? -1)") {
            guard scenePhase == .active, model.me != nil, !model.requestScoped else { return }
            await model.pollSetups()
        }
    }
}
