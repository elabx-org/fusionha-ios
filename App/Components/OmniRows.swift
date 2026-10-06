import SwiftUI
import UIKit
import FusionhaKit

// The omni search's rows: owned titles, the TMDB add lane, and their press style.

/// A TMDB result in the omni add lane: ★ rating, then Add (preview) /
/// Request / Open ↗.
struct OmniAddRow: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let close: () -> Void
    @State private var requested = false

    var body: some View {
        OmniRow(posterUrl: result.posterUrl,
                dot: result.isAnime ? Theme.kindAnime : (result.kind == .series ? Theme.kindSeries : Theme.kindMovie),
                title: result.title, year: result.year) {
            if let vote = result.voteAverage, vote > 0 {
                Text("★ \(String(format: "%.1f", vote))")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.miss)
            }
        } action: {
            action
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var action: some View {
        if result.inLibrary, let id = model.libraryItemId(for: result), !model.requestScoped {
            Button {
                close()
                model.open(id)
            } label: {
                Text("Open ↗").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .buttonStyle(.plain)
        } else if model.requestScoped {
            iconButton(requested ? "checkmark" : "paperplane", label: "Request") {
                Task {
                    do {
                        try await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: .hd))
                        requested = true
                        model.toast("Requested \(result.title)")
                    } catch {
                        model.toast("Couldn't request \(result.title)", variant: .error)
                    }
                }
            }
            .disabled(requested || result.inLibrary)
        } else {
            iconButton("plus", label: "Add") {
                close()
                model.openPreview(result)
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.92))
        .accessibilityLabel(label)
    }
}

/// An omni row: 44×66 poster, kind dot, title + year, a sub line and a
/// trailing action.
struct OmniRow<Sub: View, Action: View>: View {
    let posterUrl: String?
    let dot: Color
    let title: String
    let year: Int?
    @ViewBuilder var sub: Sub
    @ViewBuilder var action: Action

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(posterUrl, to: "w154"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle().fill(dot).frame(width: 7, height: 7)
                    (Text(title).foregroundStyle(Theme.txt)
                        + Text(year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                sub
            }
            Spacer(minLength: 8)
            action
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct OmniRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .padding(.horizontal, 8)
    }
}
