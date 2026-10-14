import SwiftUI
import UIKit
import FusionhaKit

// Parts the series Files tab (DetailSeriesFiles) and the movie Versions tab
// (DetailMovieEditions) share: the web opener, Rename files, the tier chip,
// the analysis badge and the probe formatters.

/// Opens this item in the web app (for the dialogs that live there).
@MainActor
struct DetailWebOpener {
    let model: AppModel
    let openURL: OpenURLAction
    let itemId: Int

    func callAsFunction() {
        guard let server = model.credentials?.serverURL else { return }
        openURL(server.appendingPathComponent("library/\(itemId)"))
    }
}

struct DetailRenameFilesButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            DetailGlassLabel(systemImage: "pencil", text: "Rename files", height: 36)
        }
        .buttonStyle(DetailPressStyle())
    }
}

/// The lit edition chip in a section header or file row. HD is purple, 4K cyan.
struct DetailTierChip: View {
    let tier: QualityTier
    var label: String? = nil
    var short = false

    var body: some View {
        let color = DetailTokens.tier(tier)
        Text(short ? tier.tierShort : (label ?? tier.chipLabel))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(EditionChipBackground(color: color))
    }
}

/// The spinner shown while a file's media analysis is pending (MediaInfoBadge).
struct DetailAnalysisBadge: View {
    let file: MovieFile
    var body: some View {
        if file.analysis == "pending" {
            DetailSpinner(size: 13, color: Theme.indigo, period: 0.9)
                .accessibilityLabel("Analysing")
        } else if file.analysis == "failed" {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(Theme.miss)
                .accessibilityLabel("Analysis failed")
        }
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
