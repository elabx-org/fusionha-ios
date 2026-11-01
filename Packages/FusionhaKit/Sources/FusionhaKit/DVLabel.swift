import Foundation

/// Dolby Vision profile wording for a probed file (web `dv-label.ts`). Profile 5 /
/// compat 0 has no HDR fallback (wrong colours on non-DV screens), the same proof
/// the server scores TRaSH "DV (w/o HDR fallback)" on.
public enum DVLabel {
    public static func noFallback(profile: Int?, compat: Int?) -> Bool {
        guard let profile else { return false }
        return profile == 5 || compat == 0
    }

    /// "8.1" / "5": profile 5 is written bare, its compat id is always 0.
    static func number(profile: Int?, compat: Int?) -> String {
        let suffix = compat.map { profile != 5 ? ".\($0)" : "" } ?? ""
        return "\(profile.map(String.init) ?? "")\(suffix)"
    }

    /// "P8.1" / "P5" chip sub-label; nil without a DV record.
    public static func subLabel(profile: Int?, compat: Int?) -> String? {
        profile == nil ? nil : "P\(number(profile: profile, compat: compat))"
    }

    /// "Profile 8.1 · HDR10 base" / "Profile 5 · no HDR fallback".
    public static func profileLabel(profile: Int?, compat: Int?, hdrFormat: String?) -> String {
        let note = noFallback(profile: profile, compat: compat) ? " · no HDR fallback"
            : hdrFormat == "dv hdr10" ? " · HDR10 base" : ""
        return "Profile \(number(profile: profile, compat: compat))\(note)"
    }

    /// Chip tooltip: "Dolby Vision profile 5 · no HDR fallback".
    public static func chipTitle(profile: Int?, compat: Int?) -> String {
        let note = noFallback(profile: profile, compat: compat) ? " · no HDR fallback" : ""
        return "Dolby Vision profile \(number(profile: profile, compat: compat))\(note)"
    }
}

public extension ManualImportProbe {
    /// "P8.1" / "P5"; nil without a DV record.
    var dvSubLabel: String? { DVLabel.subLabel(profile: dvProfile, compat: dvCompatId) }
    /// "Profile 8.1 · HDR10 base" / "Profile 5 · no HDR fallback".
    var dvProfileLabel: String { DVLabel.profileLabel(profile: dvProfile, compat: dvCompatId, hdrFormat: hdrFormat) }
    var dvChipTitle: String { DVLabel.chipTitle(profile: dvProfile, compat: dvCompatId) }
}
