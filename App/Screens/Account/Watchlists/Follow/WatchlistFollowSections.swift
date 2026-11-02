import SwiftUI
import FusionhaKit

/// Someone's public Letterboxd watchlist by username: the field, Preview,
/// then the 25-film sample and the start choice.
struct WatchlistFollowSections: View {
    @Environment(AppModel.self) private var model
    @Bindable var watch: WatchlistFollowModel

    var body: some View {
        Section {
            HStack(spacing: 2) {
                Text("letterboxd.com/").foregroundStyle(Theme.dim)
                TextField("username", text: $watch.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Username whose watchlist to follow")
            }
            FollowPreviewButton(reading: watch.reading, ready: watch.ready, nextAt: watch.nextPreviewAt) {
                watch.runPreview(model.client)
            }
        } header: {
            Text(FeedCopy.watchInstead)
        } footer: {
            Text(watch.error ?? "Their watchlist must be public. fusionha can’t verify who owns a username; it only reads public pages.")
                .foregroundStyle(watch.error == nil ? Theme.mut : Theme.danger)
        }
        if let preview = watch.shown {
            WatchlistPreviewRows(preview: preview)
            FeedStartSection(existing: $watch.existing, count: preview.itemCount)
        }
    }
}

/// The watchlist preview: title, film count and the 25-film sample with
/// in-library marks.
private struct WatchlistPreviewRows: View {
    let preview: LbSourcePreview

    var body: some View {
        Section {
            ForEach(Array(preview.items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.title).foregroundStyle(item.inLibrary ? Theme.mut : Theme.txt)
                    if let year = item.year { Text(String(year)).foregroundStyle(Theme.dim) }
                    Spacer(minLength: 8)
                    if item.inLibrary { Text("in library").font(.caption).foregroundStyle(Theme.text(.done)) }
                }
                .font(.subheadline)
            }
        } header: {
            HStack {
                Text(preview.title ?? "@\(preview.owner ?? "") · watchlist")
                Spacer()
                if let count = preview.itemCount { Text("\(count) films") }
            }
        } footer: {
            Text("By @\(preview.owner ?? ""). Showing a sample of 25. fusionha reads the full list once you add it.")
        }
    }
}
