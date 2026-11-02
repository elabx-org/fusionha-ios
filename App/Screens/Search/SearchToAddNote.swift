import SwiftUI

/// The add lane when the library matched and the server skipped TMDB
/// (`tmdb=auto`): a quiet line and "Search to add", which asks again with
/// `tmdb=always` (the web palette's collapsed trigger row).
struct SearchToAddNote: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Found in your library, so TMDB wasn't searched.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: action) {
                Label("Search to add", systemImage: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.i2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.pageGutter + 2)
        .padding(.vertical, 10)
        .transition(.opacity)
    }
}
