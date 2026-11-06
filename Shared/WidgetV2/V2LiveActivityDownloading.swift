import SwiftUI
import FusionhaKit

/// v2's Lock Screen Live Activity while something downloads (mock Browse ›
/// Widgets, `liveActivity`): the lead title's poster, the queue in words
/// ("fusionha · 1 downloading · 2 need you"), the title, then one bar per
/// version of that title: its ticket, a one-ink track filling in the accent,
/// and the percent, or orange and "Held" for a version waiting on you.
/// Same `DownloadsActivityAttributes` as v1, so a v1 activity (or a server
/// push) still draws when v2 takes v1's place.
struct V2LiveActivityDownloading: View {
    typealias State = DownloadsActivityAttributes.ContentState
    let state: State

    var body: some View {
        if let lead = state.rows.first {
            let bars = V2LiveActivityBars.of(state, lead: lead)
            HStack(spacing: 12) {
                V2LiveActivityPoster(mediaItemId: lead.mediaItemId)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.caption(state))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    Text(Self.title(lead, versions: bars.count))
                        .font(.system(size: 15.5, weight: .bold))
                        .lineLimit(1)
                        .padding(.top, 2)
                        .padding(.bottom, 6)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(bars, id: \.id) { V2LiveActivityBar(bar: $0) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .badgeInk(.onArt)
        }
    }

    /// "fusionha · 2 downloading · 1 need you".
    static func caption(_ state: State) -> String {
        var parts = ["fusionha"]
        if state.downloading > 0 { parts.append("\(state.downloading) downloading") }
        if state.needYou > 0 { parts.append("\(state.needYou) need you") }
        if state.paused == true { parts.append("paused") }
        return parts.joined(separator: " · ")
    }

    /// "Wicked: For Good · both editions" when both versions are on the
    /// bars, else the title and its episode.
    static func title(_ lead: State.Row, versions: Int) -> String {
        if versions > 1 { return "\(lead.title) · both editions" }
        return [lead.title, lead.sub].compactMap { $0 }.joined(separator: " · ")
    }
}

/// The lead's poster from the activity's thumbs, App Group or keychain.
struct V2LiveActivityPoster: View {
    let mediaItemId: Int

    var body: some View {
        let image = DownloadsActivityAttributes.ContentState.posterData(mediaItemId: mediaItemId)
            .flatMap { UIImage(data: $0) }
        Group {
            if let image {
                Image(uiImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.white.opacity(0.12))
            }
        }
        .frame(width: 52, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
