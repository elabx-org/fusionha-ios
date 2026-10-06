import SwiftUI
import FusionhaKit

// The episode card's per-version status chip (EpisodeStatus) and download pill.

/// EpisodeStatus: the per-edition chip on an episode card.
struct EpisodeStatusChip: View {
    let episode: Episode
    let edition: DetailEdition

    var body: some View {
        let kind = episode.status(editionId: edition.id)
        let file = episode.file(for: edition.id)
        switch kind {
        case .owned:
            DetailQualityChip(quality: file?.quality, tier: edition.tier)
        case .attention:
            DetailQualityChip(quality: file?.quality, tier: edition.tier)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.miss.opacity(0.7), lineWidth: 1.5))
                .overlay(alignment: .topTrailing) { marker("!", Theme.miss) }
        case .upgrading:
            HStack(spacing: 4) {
                DetailQualityChip(quality: file?.quality, tier: edition.tier)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.edition.opacity(0.65), lineWidth: 1.5))
                Text("↑").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.edition)
                if let target = episode.download(for: edition.id)?.releaseQuality {
                    Text(DetailText.quality(target)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.cyan)
                }
            }
        case .downloading:
            DownloadPill(download: episode.download(for: edition.id))
        case .stuck:
            Text("⚠ STUCK")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.stuck)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.stuck.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.stuck.opacity(0.55), lineWidth: 1.5))
        case .missing:
            Text("missing")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.danger.mix(0.85, .white))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.danger.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
        case .soon:
            HStack(spacing: 3) {
                Image(systemName: "clock").font(.system(size: 10))
                Text("soon")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.mut)
        }
    }

    private func marker(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(Theme.bg)
            .frame(width: 11, height: 11)
            .background(color, in: Circle())
            .offset(x: 4, y: -4)
    }
}

/// The cyan "DOWNLOADING" pill; tapping it shows the release, its client and
/// indexer and the progress, with a jump to Activity › Queue.
struct DownloadPill: View {
    @Environment(AppModel.self) private var model
    let download: EpisodeDownload?
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 5) {
                DetailSpinner(size: 10, color: Theme.grab, period: 0.9)
                Text("DOWNLOADING")
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(Theme.grab.mix(0.88, .white))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.grab.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.grab.opacity(0.55), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(download?.releaseTitle ?? "Downloading")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach([download?.client, download?.indexer].compactMap { $0 }, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                if let progress = download?.progress {
                    HStack(spacing: 8) {
                        DetailCoverageBar(total: 100, owned: Int(progress), color: Theme.grab, height: 5)
                        Text("\(Int(progress))%").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Theme.grab)
                    }
                }
                Button("Open in Activity") {
                    showing = false
                    model.tab = .activity
                    model.presentedItem = nil
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.cyan)
            }
            .padding(14)
            .frame(width: 280)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.panel2)
        }
        .accessibilityLabel("Downloading")
    }
}
