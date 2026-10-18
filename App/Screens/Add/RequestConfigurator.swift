import SwiftUI
import FusionhaKit

// MARK: - Requesters

struct RequestConfigurator: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let done: () -> Void
    @State private var tier: QualityTier = .hd
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                    .frame(width: 72, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    if let overview = result.overview {
                        Text(overview).font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(4)
                    }
                }
            }
            SegmentedPills(options: [(QualityTier.hd, "HD·1080p"), (.uhd, "UHD·4K")], selection: $tier, fill: true)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            Button {
                Task {
                    sending = true
                    do {
                        try await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: tier))
                        model.toast("Requested \(result.title)")
                        done()
                    } catch {
                        self.error = "Couldn't send the request. \(error.localizedDescription)"
                    }
                    sending = false
                }
            } label: {
                Text(sending ? "Requesting…" : "Request")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.primary, in: Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .disabled(sending)
        }
    }
}
