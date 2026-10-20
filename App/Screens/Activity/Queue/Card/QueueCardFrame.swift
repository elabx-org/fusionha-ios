import SwiftUI
import FusionhaKit

/// A single queue card's frame (web `CardShell` + `card.module.css`). Narrow
/// (under 720, the phone and the Duo's list pane): a small poster beside the
/// title, the body full width, the actions on their own row. Wide (the card's
/// own 720+ grid, the desktop layout): a 48 pt poster column, the title with
/// the actions beside it, the body beneath the title.
struct QueueCardFrame<Main: View, Aside: View>: View {
    let item: QueueItem
    @ViewBuilder var main: Main
    /// The readout / primary and the icon actions; `wide` says where they sit.
    @ViewBuilder var aside: (_ wide: Bool) -> Aside
    @Environment(\.paneSize) private var pane

    /// The card's width is the page's less its gutters.
    private var wide: Bool {
        QueueDuoRule.cardIsWide(Double(pane.width - 2 * Theme.pageGutter))
    }

    var body: some View {
        if wide {
            HStack(alignment: .top, spacing: 14) {
                QueueCardPoster(item: item, size: .lg)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        QueueCardTitle(item: item)
                        Spacer(minLength: 8)
                        aside(true)
                    }
                    main
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                QueueCardHead(item: item)
                main
                aside(false)
            }
        }
    }
}

/// Poster, title and episode (or year) of a single card.
struct QueueCardHead: View {
    let item: QueueItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            QueueCardPoster(item: item, size: .md)
            QueueCardTitle(item: item).padding(.top, 6)
            Spacer(minLength: 0)
        }
    }
}

/// The card's poster: opens the card beside the list when the queue is split,
/// the title otherwise.
struct QueueCardPoster: View {
    let item: QueueItem
    var size: ActPosterSize = .md
    @Environment(AppModel.self) private var model
    @Environment(\.queueCardOpener) private var opener

    var body: some View {
        ActPoster(url: item.posterUrl, title: item.title, size: size)
            .onTapGesture { model.openQueueCard(item, opener: opener) }
    }
}

/// The card's title and its episode or year line.
struct QueueCardTitle: View {
    let item: QueueItem
    @Environment(AppModel.self) private var model
    @Environment(\.queueCardOpener) private var opener

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                .onTapGesture { model.openQueueCard(item, opener: opener) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(opener == nil ? "Opens the title" : "Opens the download beside the list")
            if let sub = QueueCardText.subtitle(item) {
                Text(sub).font(.system(size: 15)).foregroundStyle(Theme.mut).lineLimit(2)
            }
        }
    }
}
