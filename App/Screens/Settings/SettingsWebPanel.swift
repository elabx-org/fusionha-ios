import SwiftUI
import WebKit
import FusionhaKit

/// A Settings panel that is not native yet: the web app's `/settings/<slug>`
/// in the signed-in `FusionhaWebView`.
struct SettingsWebPanel: View {
    let slug: String
    @Environment(AppModel.self) private var model
    @State private var loading = true

    var body: some View {
        Group {
            if let server = model.credentials?.serverURL {
                FusionhaWebView(url: server.appendingPathComponent("settings").appendingPathComponent(slug),
                                server: server, token: model.credentials?.token, loading: $loading)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay {
                        if loading { ProgressView().controlSize(.large).tint(Theme.mut) }
                    }
            } else {
                Text("Not signed in.").foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .navigationTitle(SettingsNav.panel(slug)?.title ?? slug)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let server = model.credentials?.serverURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: server.appendingPathComponent("settings").appendingPathComponent(slug)) {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
        }
    }
}
