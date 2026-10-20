import Foundation

/// The desktop table's cells (web `FileRow.tsx`: Video, Audio, Group · service),
/// as text. The probe wins over the name when it read the file.
public enum ManualImportTableCells {
    /// "2160p · DV P8 · HEVC 10-bit" from the probe, else the name's range and codec.
    public static func video(_ row: ManualImportRow) -> String {
        if let p = row.probe, p.isOK {
            var parts: [String] = []
            if let h = p.height { parts.append("\(h)p") }
            let dr = ManualImportCompare.dynamicRange(p)
            if dr == "DV" { parts.append(p.dvProfile.map { "DV P\($0)" } ?? "DV") } else if dr != "SDR" { parts.append(dr) }
            let codec = ManualImportCompare.video(p)
            if !codec.isEmpty { parts.append(codec) }
            return parts.isEmpty ? "—" : parts.joined(separator: " · ")
        }
        var parts: [String] = row.parsed.resolution.map { ["\($0)p"] } ?? []
        parts += (row.parsed.dynamicRange ?? []).map { $0 == "HDR10PLUS" ? "HDR10+" : $0 }
        if let codec = row.parsed.videoCodec { parts.append(codec) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    /// The probe's audio, else the name's label.
    public static func audio(_ row: ManualImportRow) -> String {
        if let p = row.probe, p.isOK, p.audioCodec != nil || p.audioLabel != nil { return ManualImportCompare.audioText(p) }
        return row.parsed.audioLabel ?? "—"
    }

    /// Release group · service (or Remux / source) · REPACK / PROPER (`GroupCell`).
    public static func group(_ row: ManualImportRow) -> String {
        let p = row.parsed
        guard p.releaseGroup != nil || p.streamingService != nil || p.source != nil else { return "no group in name" }
        let service = p.streamingService ?? (p.isRemux == true ? "Remux" : p.source)
        let rev = p.isRepack == true ? "REPACK" : (p.isProper == true ? "PROPER" : nil)
        return [p.releaseGroup ?? "—", service, rev].compactMap { $0 }.joined(separator: " · ")
    }
}
