import SwiftUI
import UIKit
import FusionhaKit

// The omni search's rows: owned titles, the TMDB add lane, and their press style.

/// A TMDB result in the omni add lane: ★ rating, then Open (owned) or Add and
/// Request, each gated on its own capability (web `rowActions`; L15: a user
/// with both sees two buttons). The row body opens the title, else the
/// preview (add), else the request modal (tiers, seasons, note), as on the web.
struct OmniAddRow: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let close: () -> Void
    let request: (MediaSearchResult) -> Void

    var body: some View {
        Button(action: primary) {
            row
        }
        .buttonStyle(OmniRowStyle())
    }

    private var row: some View {
        OmniRow(posterUrl: result.posterUrl,
                dot: result.isAnime ? Theme.kindAnime : (result.kind == .series ? Theme.kindSeries : Theme.kindMovie),
                title: result.title, year: result.year) {
            if let vote = result.voteAverage, vote > 0 {
                Text("★ \(String(format: "%.1f", vote))")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.miss)
            }
        } action: {
            HStack(spacing: 2) {
                ForEach(actions, id: \.self) { action in
                    button(for: action)
                }
            }
        }
    }

    private var openable: Int? {
        guard result.inLibrary, !model.requestScoped else { return nil }
        return model.libraryItemId(for: result)
    }

    private var canAdd: Bool { model.me?.hasCapability("add") == true }
    private var canRequest: Bool { model.me?.hasCapability("request") == true }

    private var actions: [OmniActions.Action] {
        OmniActions.addRowActions(openable: openable != nil, canAdd: canAdd, canRequest: canRequest)
    }

    private func primary() {
        switch OmniActions.addRowPrimary(openable: openable != nil, canAdd: canAdd, canRequest: canRequest) {
        case .open:
            if let id = openable {
                close()
                model.open(id)
            }
        case .preview:
            close()
            model.openPreview(result)
        case .request:
            request(result)
        case .none:
            break
        }
    }

    @ViewBuilder
    private func button(for action: OmniActions.Action) -> some View {
        switch action {
        case .open:
            OmniIconButton(symbol: "arrow.up.right", label: "Open", action: primary)
        case .add:
            // Web #12: "+" opens the Add flow directly; the row opens the preview.
            OmniIconButton(symbol: "plus", label: "Add") {
                close()
                model.openAdd(result)
            }
        case .request:
            OmniIconButton(symbol: "paperplane", label: "Request") { request(result) }
        }
    }
}

/// The omni rows' trailing action (web `IconButton` md): one round 30 pt
/// button for Open, Add and Request, where the glyph is the only difference.
/// The hit area is 44 pt.
struct OmniIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.txt)
                .frame(width: 30, height: 30)
                .background(Theme.panel2, in: Circle())
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
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
                        + Text(verbatim: year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
                sub
            }
            Spacer(minLength: 8)
            action
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
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
