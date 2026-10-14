import SwiftUI
import WebKit
import FusionhaKit

/// The fusionha web app inside the app, signed in. Two things make the page
/// open as the signed-in user:
/// - the `fusionha_session` cookie captured at sign-in, when there is one;
/// - the device's API token, added as `X-Api-Key` to the page's own same-origin
///   `fetch` / XHR calls. The server accepts that token on every route the web
///   app uses (`/auth/me` included), so the page stays signed in after the
///   session cookie expires. The token never goes to another origin.
/// Links that leave the server open in Safari.
struct FusionhaWebView: UIViewRepresentable {
    let url: URL
    let server: URL
    let token: String?
    @Binding var loading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(server: server, loading: $loading) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        if let token, let script = Self.apiKeyScript(token: token) {
            config.userContentController.addUserScript(script)
        }
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

    /// Runs before the page's own scripts: wraps `fetch` and `XMLHttpRequest`
    /// so same-origin requests carry `X-Api-Key` unless they already set one.
    static func apiKeyScript(token: String) -> WKUserScript? {
        guard let data = try? JSONEncoder().encode(token), let key = String(data: data, encoding: .utf8) else { return nil }
        let source = """
        (() => {
          const KEY = \(key), HEADER = 'X-Api-Key';
          const sameOrigin = (u) => { try { return new URL(u, location.href).origin === location.origin; } catch (e) { return false; } };
          const origFetch = window.fetch.bind(window);
          window.fetch = (input, init) => {
            const target = typeof input === 'string' ? input : (input && input.url) || String(input);
            if (sameOrigin(target)) {
              const opts = Object.assign({}, init || {});
              const headers = new Headers(opts.headers || (input instanceof Request ? input.headers : undefined));
              if (!headers.has(HEADER)) headers.set(HEADER, KEY);
              opts.headers = headers;
              return origFetch(input, opts);
            }
            return origFetch(input, init);
          };
          const open = XMLHttpRequest.prototype.open, send = XMLHttpRequest.prototype.send;
          const setHeader = XMLHttpRequest.prototype.setRequestHeader;
          XMLHttpRequest.prototype.open = function (method, u) { this.__fhSame = sameOrigin(u); this.__fhKey = false; return open.apply(this, arguments); };
          XMLHttpRequest.prototype.setRequestHeader = function (name, value) {
            if (String(name).toLowerCase() === HEADER.toLowerCase()) this.__fhKey = true;
            return setHeader.apply(this, arguments);
          };
          XMLHttpRequest.prototype.send = function () {
            if (this.__fhSame && !this.__fhKey) setHeader.call(this, HEADER, KEY);
            return send.apply(this, arguments);
          };
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let server: URL
        let loading: Binding<Bool>
        init(server: URL, loading: Binding<Bool>) { self.server = server; self.loading = loading }

        /// Stay on the fusionha server; a link anywhere else opens in Safari.
        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let target = navigationAction.request.url, navigationAction.navigationType == .linkActivated,
               target.host != server.host, target.scheme?.hasPrefix("http") == true {
                await UIApplication.shared.open(target)
                return .cancel
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading.wrappedValue = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loading.wrappedValue = false
        }
    }
}

/// A full-height sheet with a fusionha web page (Manual import, account): the
/// signed-in web view under a glass close button.
struct FusionhaWebSheet: View {
    let url: URL
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg.ignoresSafeArea()
            if let server = model.credentials?.serverURL {
                FusionhaWebView(url: url, server: server, token: model.credentials?.token, loading: $loading)
                    .ignoresSafeArea(edges: .bottom)
            }
            if loading {
                ProgressView().controlSize(.large).tint(Theme.mut)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                Spacer()
                Link(destination: url) {
                    Image(systemName: "safari")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.txt)
                        .frame(width: 36, height: 36)
                }
                .glassControl()
                .accessibilityLabel("Open in Safari")
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.top, 8)
        }
        .presentationDragIndicator(.visible)
    }
}
