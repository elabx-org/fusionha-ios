import SwiftUI
import WidgetKit
import FusionhaKit

/// The v2 Up next large widget's top (mock `airingWidget` `.feat`): the next
/// airing on its own poster, blurred and darkened behind it, with "Airing
/// tonight · 20:00", the title, the episode and its tickets in white. In a
/// tinted or clear Home Screen the blur gives way to a faint fill.
struct V2UpNextFeature: View {
    let row: UpNextRow
    @Environment(\.widgetRenderingMode) private var mode
    @Environment(\.widgetAccentPreview) private var preview

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 12) {
                WidgetPoster(data: row.poster, radius: 9)
                    .frame(width: 52, height: 78)
                    .shadow(color: .black.opacity(0.4), radius: 7, y: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.kicker(item))
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.9)
                        .widgetAccentable()
                    Text(item.title)
                        .font(.system(size: 19, weight: .bold))
                        .tracking(-0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                        .font(.system(size: 13))
                        .opacity(0.85)
                        .lineLimit(1)
                    WidgetEditionTickets(editions: item.pills, ink: .onArt)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { backdrop }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var backdrop: some View {
        if mode == .accented || preview {
            Color.white.opacity(0.14)
        } else if let data = row.poster, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.2)
                .blur(radius: 14)
                .saturation(1.3)
                .overlay(Color.black.opacity(0.45))
        } else {
            Color(hex: 0x1E1B2E)
        }
    }

    /// "Airing tonight · 20:00", "Airing tomorrow · 21:00", "Next · Thu", or
    /// for a release, "Out today · Digital".
    static func kicker(_ item: UpNextItem) -> String {
        let day = WidgetDay.label(item.airDate, hasTime: item.hasTime, long: true)
        let time = item.hasTime ? item.airDate.formatted(.dateTime.hour().minute()) : nil
        let near = ["Tonight", "Today", "Tomorrow"].contains(day)
        if item.isMovie { return near ? "Out \(day.lowercased())" : "Out \(day)" }
        let head = near ? "Airing \(day.lowercased())" : "Next · \(day)"
        return [head, time].compactMap { $0 }.joined(separator: " · ")
    }
}
