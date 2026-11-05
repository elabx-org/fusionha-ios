import SwiftUI
import FusionhaKit

/// One row of the Files tab's season card (mock `.frow`): `E01`, the title
/// over a facts line (group · quality · video · audio, v1's
/// `EpisodeFileFacts`: the server's probe first, the filename after), and
/// the size. A missing aired episode keeps its place, dimmed, "Missing ·
/// aired today" and a dash; one still to air says "Airs Tue 10 Nov". A dead
/// link says so in orange.
struct V2EpisodeFileLine: View {
    @Environment(\.pagePalette) private var page
    let row: SeasonFileRow
    let tier: QualityTier

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .frame(minWidth: 32, alignment: .leading)
                .fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(row.isMissing ? muted : ink)
                    .lineLimit(1)
                facts
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.file.map { DetailText.bytes($0.size) } ?? "—")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .opacity(row.isMissing && row.episodes.first?.hasAired() == false ? 0.6 : 1)
        .accessibilityHint(row.isMissing ? "Opens the episode" : "Shows the file's details")
    }

    @ViewBuilder
    private var facts: some View {
        if let file = row.file {
            let facts = EpisodeFileFacts(file: file, tier: tier)
            let parts = [facts.group, facts.quality, facts.video, facts.audio].compactMap { $0 }
            if facts.deadLink {
                Text((["Dead link"] + parts).joined(separator: " · ")).foregroundStyle(Theme.stuck)
            } else if facts.analysing && parts.isEmpty {
                Text("Reading media info…").foregroundStyle(muted)
            } else {
                Text(parts.isEmpty ? "No media facts yet" : parts.joined(separator: " · ")).foregroundStyle(muted)
            }
        } else {
            Text(Self.gapNote(row.episodes.first)).foregroundStyle(muted)
        }
    }

    /// "Missing · aired today" / "Missing · aired Wed 28 Oct" / "Airs Tue 10 Nov".
    static func gapNote(_ episode: Episode?, now: Date = Date()) -> String {
        guard let episode, let date = episode.airInstant else { return "Missing" }
        let day: String
        if Calendar.current.isDateInToday(date) {
            day = "today"
        } else if Calendar.current.isDateInYesterday(date) {
            day = "yesterday"
        } else if Calendar.current.isDateInTomorrow(date) {
            day = "tomorrow"
        } else {
            day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return episode.hasAired(now: now) ? "Missing · aired \(day)" : "Airs \(day)"
    }
}
