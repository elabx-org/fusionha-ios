import SwiftUI

/// The web's avatar menu (Settings, Log out), as a glass toolbar button.
struct AccountButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            if let server = model.credentials?.serverURL {
                Section(server.host() ?? server.absoluteString) {
                    Button("Open web app", systemImage: "safari") { openURL(server) }
                    Button("Settings", systemImage: "gearshape") {
                        openURL(server.appendingPathComponent("settings"))
                    }
                }
            }
            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                model.signOut()
            }
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Account")
    }
}
