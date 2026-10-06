import SwiftUI
import UIKit
import WidgetKit
import FusionhaKit

// MARK: - User menu

/// The avatar and its menu (UserMenu.tsx): name + "Administrator", Settings,
/// Reset cache & reload, Log out. The amber dot shows when something needs
/// attention. "Open web app" and the version are iOS-only extras.
struct AvatarMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingSettings = SettingsScreenshot.openAtLaunch
    @State private var showingWidgets = WidgetDiagnosticsView.openAtLaunch
    /// Keychain + App Group probes are synchronous IPC; this menu's body runs on
    /// every screen, so they are read once, off the main thread.
    @State private var diagnostics = ""

    var body: some View {
        Menu {
            if let me = model.me {
                Section {
                    Button {} label: {
                        Text(me.username)
                        if me.isAdmin { Text("Administrator") }
                    }
                    .disabled(true)
                }
            }
            Section {
                Button("Account", systemImage: "person.crop.circle") { model.showingAccount = true }
            }
            Section {
                if model.credentials != nil, !model.requestScoped {
                    Button("Settings", systemImage: "slider.horizontal.3") {
                        showingSettings = true
                    }
                }
                // The in-app docs (`/docs`) live on the web app; open them there.
                if let server = model.credentials?.serverURL {
                    Button("Documentation", systemImage: "book.closed") {
                        openURL(server.appendingPathComponent("docs"))
                    }
                }
            }
            Section {
                Button("Reset cache & reload", systemImage: "arrow.clockwise") {
                    Task { await model.resetCacheAndReload() }
                }
            }
            Section {
                Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task { await model.logOut() }
                }
            }
            Section("Version \(Bundle.main.appVersion)\(diagnostics.isEmpty ? "" : " · \(diagnostics)")") {
                if let server = model.credentials?.serverURL {
                    Button("Open web app", systemImage: "safari") { openURL(server) }
                }
                Button("Widget diagnostics", systemImage: "stethoscope") { showingWidgets = true }
            }
        } label: {
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
                .contentShape(Circle())
        }
        .accessibilityLabel(model.attentionCount > 0 ? "Account, \(model.attentionCount) need attention" : "Account")
        .task(id: model.credentials?.serverURL) {
            diagnostics = await Task.detached(priority: .utility) { CredentialStore.diagnostics() }.value
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView(client: model.client, initialPanel: SettingsScreenshot.panel)
        }
        .sheet(isPresented: $showingWidgets) {
            WidgetDiagnosticsView()
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        // A deep link closes these so its sheet can show (DeepLink.swift).
        .onChange(of: showingSettings || showingWidgets) { _, open in model.avatarCoverOpen = open }
        .onChange(of: model.linkCloseTick) {
            showingSettings = false
            showingWidgets = false
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
                Image(uiImage: image).resizable().scaledToFill().clipShape(Circle())
            } else {
                Text(me?.initials ?? "")
                    .font(.system(size: size * 13 / 32, weight: .bold))
                    .foregroundStyle(.white)
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
