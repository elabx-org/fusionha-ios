import SwiftUI
import FusionhaKit

// The movie reveals (EditionCoverage.tsx): every edition as a washed card with
// the disk footprint (D.9), or one edition's card (D.10).

enum MovieCardStatus {
    case done, grabbing, wanted, soon, upgrading

    var color: Color {
        switch self {
        case .done: return Theme.done
        case .grabbing: return Theme.grab
        case .wanted: return Theme.miss
        case .soon: return Theme.unaired
        case .upgrading: return Theme.edition
        }
    }

    var pill: DetailStatePillKind {
        switch self {
        case .done: return .ok("Downloaded")
        case .grabbing: return .part("Downloading")
        case .wanted: return .want
        case .soon: return .soon
        case .upgrading: return .upgrading
        }
    }

    var word: String {
        switch self {
        case .done, .upgrading: return "Downloaded"
        case .grabbing: return "Downloading"
        case .wanted: return "Wanted"
        case .soon: return "Upcoming"
        }
    }
}

extension DetailStore {
    /// `movieCardStatus`: file → done; live grab → grabbing; else wanted vs upcoming by `grabbable`.
    func movieStatus(_ edition: DetailEdition) -> MovieCardStatus {
        if edition.downloadState == "upgrading" { return .upgrading }
        if edition.movieFile != nil {
            return activeQueueEditionIds.contains(edition.id) ? .upgrading : .done
        }
        if edition.downloadState == "downloading" || activeQueueEditionIds.contains(edition.id) { return .grabbing }
        return edition.grabbable == false ? .soon : .wanted
    }
}

// MARK: - D.9 movie All

struct MovieAllReveal: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let editions: [DetailEdition]

    var body: some View {
        let owned = editions.filter { $0.movieFile != nil }
        let bytes = owned.compactMap { $0.movieFile?.size }.reduce(0, +)
        VStack(alignment: .leading, spacing: 0) {
            RevealHeader(label: "All editions", count: "\(owned.count) of \(editions.count) · \(DetailText.bytes(bytes))",
                         detail: detail, railEdition: nil) { DetailDualDots() }
            VStack(spacing: 14) {
                ForEach(editions) { edition in
                    MovieEditionCard(detail: detail, edition: edition)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 2)
            .padding(.bottom, 14)
            if owned.count > 0 {
                footprint(owned, total: bytes)
            }
        }
    }

    private func footprint(_ owned: [DetailEdition], total: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Disk footprint · \(DetailText.bytes(total)) total".uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(owned) { edition in
                        Rectangle()
                            .fill(edition.tier == .hd ? Theme.edition : Theme.grab)
                            .frame(width: total > 0 ? geo.size.width * CGFloat((edition.movieFile?.size ?? 0) / total) : 0)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            .background(Theme.txt.opacity(0.09), in: Capsule())
            FlowRow(spacing: 16, lineSpacing: 6) {
                ForEach(owned) { edition in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(edition.tier == .hd ? Theme.edition : Theme.grab)
                            .frame(width: 9, height: 9)
                        (Text(edition.label + " ").foregroundColor(Theme.mut)
                            + Text(DetailText.bytes(edition.movieFile?.size)).font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.txt))
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
        .padding(.horizontal, 15)
        .padding(.bottom, 14)
    }
}

// MARK: - D.10 scoped movie

struct ScopedMovieReveal: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition

    var body: some View {
        let status = store.movieStatus(edition)
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 0) {
            RevealHeader(label: edition.label, labelColor: DetailTokens.tier(edition.tier),
                         count: "\(status.word) · target \(cutoff)", detail: detail, railEdition: edition,
                         showsRail: false) {
                DetailDot(color: DetailTokens.tier(edition.tier), size: 9)
            }
            MovieEditionCard(detail: detail, edition: edition)
                .padding(.horizontal, 15)
                .padding(.bottom, 14)
        }
    }
}

// MARK: - Edition card

struct MovieEditionCard: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let edition: DetailEdition

    var body: some View {
        let status = store.movieStatus(edition)
        let tierColor = edition.tier == .hd ? Theme.edition : Theme.grab
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    DetailDot(color: tierColor, size: 9)
                    Text(edition.tier.chipLabel).font(.system(size: 15, weight: .heavy)).foregroundStyle(tierColor)
                    if !edition.versionKey.isEmpty { DetailVersionTag(text: edition.versionKey) }
                    Spacer(minLength: 6)
                    DetailStatePill(kind: status.pill)
                }
                if let file = edition.movieFile {
                    fileBody(file)
                } else {
                    wantedBody(status)
                }
            }
            .padding(16)

            VStack(spacing: 0) {
                metaRow("Root folder", store.rootPath(edition))
                metaRow("Quality profile", store.profileName(edition.qualityProfileId))
                cutoffRow
                if edition.movieFile != nil {
                    let event = grabbedEvent
                    metaRow(event.label, event.value)
                }
            }

            footer(status)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .background { wash(status) }
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line))
    }

    @ViewBuilder
    private func wash(_ status: MovieCardStatus) -> some View {
        if status == .done {
            Theme.panel2
        } else {
            LinearGradient(stops: [
                .init(color: status.color.mix(0.13, Theme.panel2), location: 0),
                .init(color: Theme.panel2, location: 0.42),
            ], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func fileBody(_ file: MovieFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Text(DetailText.quality(file.quality))
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(DetailTokens.badgeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(badgeFill, in: RoundedRectangle(cornerRadius: 8))
                Text(DetailText.bytes(file.size))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                if let res = DetailText.resolution(file.quality) {
                    Text("· \(res)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.mut)
                }
            }
            let chips = mediaChips(file)
            if !chips.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(chips.indices, id: \.self) { i in
                        Text(chips[i].0)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(chips[i].1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(chips[i].1.opacity(0.35)))
                    }
                }
            }
        }
    }

    private var badgeFill: LinearGradient {
        if edition.tier == .hd {
            return LinearGradient(colors: [Theme.indigo, Theme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Theme.grab.mix(0.55, .black), Theme.grab], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Release group, codec, audio, HDR (`movieMediaChips`).
    private func mediaChips(_ file: MovieFile) -> [(String, Color)] {
        var chips: [(String, Color)] = []
        if let group = file.releaseGroup, !group.isEmpty { chips.append((group, Theme.edition)) }
        let probe = file.mediaInfo?.probe
        if let codec = DetailMediaFacts.codec(probe) { chips.append((codec, Theme.txt)) }
        if let audio = DetailMediaFacts.audio(probe) { chips.append((audio, Theme.cyan)) }
        if let range = DetailMediaFacts.range(probe), range != "SDR" { chips.append((range, Theme.onair)) }
        return chips
    }

    @ViewBuilder
    private func wantedBody(_ status: MovieCardStatus) -> some View {
        let profile = store.profileName(edition.qualityProfileId)
        let cutoff = store.cutoff(edition.qualityProfileId).map { DetailText.quality($0) } ?? "—"
        VStack(alignment: .leading, spacing: 6) {
            if status == .soon {
                let stage = (edition.availableStage ?? "release").capitalized
                let date = edition.availableFrom.flatMap { DetailText.instant($0) }?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "TBA"
                HStack(spacing: 6) {
                    Image(systemName: "clock").detailPulse(low: 0.4, high: 1, period: 2)
                    Text("Upcoming — \(stage) \(date)")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.unaired)
                Text("Monitored · auto-grabs on release · target \(profile)")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else if let released = DetailText.instant(detail.releaseDate), released <= Date() {
                HStack(spacing: 6) {
                    Image(systemName: "clock").detailPulse(low: 0.4, high: 1, period: 2)
                    Text("Released \(released.formatted(.dateTime.month(.abbreviated).day().year())) · wanted")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.color)
                Text("No file yet · target \(profile) · cutoff \(cutoff)")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                Text("No \(edition.tier.chipLabel) file yet")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(status.color)
                Text("Target: \(profile) · cutoff \(cutoff)")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
    }

    private var cutoffRow: some View {
        let cutoff = store.cutoff(edition.qualityProfileId)
        let met = DetailText.meetsCutoff(edition.movieFile?.quality, cutoff: cutoff)
        return metaRow("Cutoff", cutoff.map { DetailText.quality($0) } ?? "—", color: met ? Theme.done : Theme.txt, check: met)
    }

    /// The latest GRABBED/IMPORTED event for this edition (`editionGrabbed`).
    private var grabbedEvent: (label: String, value: String) {
        let events = (detail.history ?? []).filter {
            $0.editionId == edition.id && ($0.eventType == "GRABBED" || $0.eventType == "IMPORTED")
        }
        guard let latest = events.max(by: { $0.createdAt < $1.createdAt }) else { return ("Grabbed", "—") }
        return (latest.eventType == "IMPORTED" ? "Imported" : "Grabbed", DetailText.relative(latest.createdAt))
    }

    private func metaRow(_ key: String, _ value: String, color: Color = Theme.txt, check: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.6).foregroundStyle(Theme.dim)
            HStack(spacing: 5) {
                Text(value).font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundStyle(color)
                    .lineLimit(2).truncationMode(.middle)
                if check { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(color) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func footer(_ status: MovieCardStatus) -> some View {
        HStack(spacing: 12) {
            PerEditionRail(detail: detail, edition: edition)
            if let file = edition.movieFile {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(DetailText.resolution(file.quality) ?? edition.tier.shortLabel) ·")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                    Text(DetailText.bytes(file.size)).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.txt)
                }
                .fixedSize()
            } else {
                Text(edition.grabbable == false ? "search enabled once available" : "grabs the best release automatically")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim)
                    .frame(maxWidth: 120, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// The probe formatters (episode-file-info.ts).
enum DetailMediaFacts {
    static func codec(_ probe: FileProbe?) -> String? {
        guard let codec = probe?.videoCodec, !codec.isEmpty else { return nil }
        let map = ["h264": "h264", "hevc": "h265", "h265": "h265", "av1": "AV1", "mpeg2": "MPEG-2", "vc1": "VC-1"]
        return map[codec.lowercased()] ?? codec
    }

    static func audio(_ probe: FileProbe?) -> String? {
        guard let probe else { return nil }
        var parts: [String] = []
        if let codec = probe.audioCodec, !codec.isEmpty {
            let map = ["eac3": "EAC3", "ac3": "AC3", "truehd": "TrueHD", "dts": "DTS", "aac": "AAC", "flac": "FLAC", "opus": "Opus", "mp3": "MP3"]
            parts.append(map[codec.lowercased()] ?? codec.uppercased())
        }
        if let ch = probe.audioChannels, ch.isFinite {
            let map: [Int: String] = [1: "1.0", 2: "2.0", 6: "5.1", 7: "6.1", 8: "7.1"]
            parts.append(map[Int(ch)] ?? "\(Int(ch)).0")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// A probed file with no HDR metadata is SDR; no probe → nil.
    static func range(_ probe: FileProbe?) -> String? {
        guard let probe else { return nil }
        guard let hdr = probe.hdrFormat, !hdr.isEmpty else { return "SDR" }
        let map = ["dv": "DV", "hdr10": "HDR10", "hdr10+": "HDR10+", "hlg": "HLG"]
        return map[hdr.lowercased()] ?? hdr.uppercased()
    }

    static func languages(_ probe: FileProbe?) -> String? {
        guard let langs = probe?.audioLanguages, !langs.isEmpty else { return nil }
        return langs.joined(separator: ", ")
    }
}
