import SwiftUI
import UIKit
import WebKit
import FusionhaKit

// MARK: YouTube player

/// A YouTube embed (trailer sheet and the Preview's inline trailer).
struct YouTubePlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: ()) {
        // Stop playback when the sheet closes.
        view.loadHTMLString("", baseURL: nil)
    }
}

/// `TrailerModal`: a bottom sheet with the 16:9 embed.
struct TrailerSheet: View {
    let title: String
    let key: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("Trailer").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.mut)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.bottom, 14)
            if let url = URL(string: "https://www.youtube.com/embed/\(key)?autoplay=1&rel=0&playsinline=1") {
                YouTubePlayer(url: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .background(Theme.panel)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
