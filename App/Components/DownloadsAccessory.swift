import SwiftUI
import FusionhaKit

/// "Now downloading" strip above the tab bar. Tap → Activity.
struct DownloadsAccessory: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.tab = .activity
        } label: {
            HStack(spacing: 10) {
                if let top = model.queue.first {
                    PosterImage(url: TMDBImage.resized(top.posterUrl, to: "w92"))
                        .frame(width: 24, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(top.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            EditionChip(tier: top.tier)
                        }
                        ProgressView(value: top.fraction)
                            .tint(top.stalled ? Theme.stuck : Theme.grab)
                    }
                    if model.queueTotal > 1 {
                        Text("+\(model.queueTotal - 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                    Text("Nothing downloading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.queue.first.map { "Downloading \($0.title), \(Int($0.progress)) percent" } ?? "Nothing downloading")
    }
}
