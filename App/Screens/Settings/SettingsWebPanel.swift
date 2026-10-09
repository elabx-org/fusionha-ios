import SwiftUI
import WebKit
import FusionhaKit

/// A Settings panel that is not native yet: the web app's `/settings/<slug>`
/// in an in-app web view. The `fusionha_session` cookie captured at sign-in is
/// put in the web view's cookie store first, so the page opens signed in; with
/// no cookie it simply shows the web login (which then persists on its own).
struct SettingsWebPanel: View {
    let slug: String
    @Environment(AppModel.self) private var model
    @State private var loading = true

    var body: some View {
        Group {
            if let server = model.credentials?.serverURL {
                SettingsWebView(url: server.appendingPathComponent("settings").appendingPathComponent(slug),
                                server: server, loading: $loading)
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

struct SettingsWebView: UIViewRepresentable {
    let url: URL
    let server: URL
    @Binding var loading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(loading: $loading) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = UIColor(Theme.bg)
        view.scrollView.backgroundColor = UIColor(Theme.bg)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        let request = URLRequest(url: url)
        if let cookie = Self.sessionCookie(for: server) {
            config.websiteDataStore.httpCookieStore.setCookie(cookie) { view.load(request) }
        } else {
            view.load(request)
        }
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    /// The stored `fusionha_session` cookie, when it belongs to this server.
    static func sessionCookie(for server: URL) -> HTTPCookie? {
        guard let session = WebSessionStore.load(), session.serverURL.host == server.host,
              let host = server.host else { return nil }
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: APIClient.sessionCookieName,
            .value: session.token,
            .domain: host,
            .path: "/",
            .expires: Date().addingTimeInterval(30 * 24 * 3600),
        ]
        if server.scheme == "https" { props[.secure] = "TRUE" }
        return HTTPCookie(properties: props)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let loading: Binding<Bool>
        init(loading: Binding<Bool>) { self.loading = loading }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loading.wrappedValue = false
        }
    }
}
