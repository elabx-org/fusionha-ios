import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

// MARK: - User menu

/// The avatar and its account sheet (UserMenu.tsx's items plus This iPhone).
/// The amber dot shows when something needs attention. The sheet is a short
/// glass sheet; Settings, Account and Widgets open once it has closed.
struct AvatarMenu: View {
    @Environment(AppModel.self) private var model
    @State private var showingSheet = false
    @State private var pending: AccountHubSheet.Destination?
    @State private var showingSettings = SettingsScreenshot.openAtLaunch
    @State private var settingsPanel = SettingsScreenshot.panel
    @State private var showingWidgets = WidgetDiagnosticsView.openAtLaunch
    /// Keychain + App Group probes are synchronous IPC; this view's body runs
    /// on every screen, so they are read once, off the main thread.
    @State private var diagnostics = ""

    var body: some View {
        Button { showingSheet = true } label: { label }
            .buttonStyle(.plain)
            .accessibilityLabel(model.attentionCount > 0 ? "Account, \(model.attentionCount) need attention" : "Account")
            .task(id: model.credentials?.serverURL) {
                diagnostics = await Task.detached(priority: .utility) { CredentialStore.diagnostics() }.value
            }
            .sheet(isPresented: $showingSheet, onDismiss: openPending) {
                AccountHubSheet(diagnostics: diagnostics) { pending = $0 }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView(client: model.client, initialPanel: settingsPanel)
            }
            .sheet(isPresented: $showingWidgets) {
                WidgetDiagnosticsView()
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            // A deep link closes these so its sheet can show (DeepLink.swift).
            .onChange(of: showingSheet || showingSettings || showingWidgets) { _, open in model.avatarCoverOpen = open }
            .onChange(of: model.linkCloseTick) {
                pending = nil
                showingSheet = false
                showingSettings = false
                showingWidgets = false
            }
    }

    private var label: some View {
        Avatar(me: model.me, size: 32)
            .overlay(alignment: .topTrailing) {
                if model.attentionCount > 0 && !model.requestScoped {
                    Circle()
                        .fill(Theme.miss)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2).padding(-2))
                        .offset(x: 1, y: -1)
                }
            }
            .frame(width: 32, height: 32)
            .padding(6)
            .contentShape(Circle())
            .padding(-6)
    }

    private func openPending() {
        guard let destination = pending else { return }
        pending = nil
        switch destination {
        case .settings(let panel):
            settingsPanel = panel
            showingSettings = true
        case .account:
            model.showingAccount = true
        case .widgets:
            showingWidgets = true
        }
    }
}

/// The 32pt gradient-initials avatar (13/700 white), or the Plex thumb from
/// `GET /api/v1/users/{id}/avatar`, fetched with this device's credentials.
struct Avatar: View {
    @Environment(AppModel.self) private var model
    let me: Me?
    var size: CGFloat = 32
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Theme.fusion)
            if let image {
                Image(uiImage: PosterWashRenderer.washed(image)).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(me?.initials ?? "")
                    .font(.system(size: size * 13 / 32, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.line))
        .task(id: me?.id) {
            guard let me, me.thumb != nil, let client = model.client else { image = nil; return }
            if let data = try? await client.avatarData(userId: me.id) { image = UIImage(data: data) }
        }
    }
}
