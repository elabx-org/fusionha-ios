import SwiftUI
import FusionhaKit

/// One source (web `SourceRow`): the provider tile, the name, `owner · mini ·
/// N to review` (the review part amber), then ONE status: a dot and its word.
struct WatchlistsSourceRow: View {
    let view: AutoSourceView
    var selected = false

    var body: some View {
        HStack(spacing: 12) {
            ProviderTile(isPlex: view.isPlex)
            // The state beside the name; in a narrow column, under it.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    names.frame(minWidth: 150, idealWidth: 150, alignment: .leading)
                    Spacer(minLength: 0)
                    SourceStateLabel(state: view.state)
                }
                VStack(alignment: .leading, spacing: 4) {
                    names
                    SourceStateLabel(state: view.state)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(view.name).font(.body.weight(.semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            subtitle.font(.caption).lineLimit(1)
        }
    }

    private var subtitle: Text {
        let sub = view.subtitle
        guard let review = view.reviewText else { return Text(sub).foregroundStyle(Theme.mut) }
        let lead = sub.isEmpty ? "" : "\(sub) · "
        return Text(lead).foregroundStyle(Theme.mut) + Text(review).fontWeight(.semibold).foregroundStyle(Theme.missText)
    }
}

/// The dot and the state word (web `STATE_TOKEN` / `STATE_TEXT_TOKEN`): the
/// word in the status's text shade, the quiet states in `dim`.
struct SourceStateLabel: View {
    let state: AutoSourceState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.tone?.color ?? Theme.dim)
                .frame(width: 7, height: 7)
            Text(state.word)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text(state.tone))
        }
        .fixedSize()
    }
}

/// The provider tile: Letterboxd's three circles, Plex's list mark.
struct ProviderTile: View {
    let isPlex: Bool
    var size: CGFloat = 30

    var body: some View {
        Group {
            if isPlex {
                WatchlistMarkGlyph(mark: .list, size: size * 0.55).foregroundStyle(WatchlistMark.list.ink)
            } else {
                WatchlistMarkGlyph(mark: .letterboxd, size: size * 0.58).foregroundStyle(WatchlistMark.letterboxd.ink)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).strokeBorder(Theme.line))
        .accessibilityHidden(true)
    }
}
