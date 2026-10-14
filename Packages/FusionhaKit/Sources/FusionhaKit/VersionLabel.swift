import Foundation

/// The queue and history version label (fusionha 0.4.192+): edition first,
/// then the tier word, e.g. `Extended · HD`. `Standard` is named only when the
/// title tracks more than one edition; otherwise a Standard version is just
/// its tier (`4K`, `HD`).
public enum VersionLabel {
    public static func text(tier: QualityTier, edition: String?, multipleEditions: Bool = false) -> String? {
        let cut = edition?.trimmingCharacters(in: .whitespaces) ?? ""
        if !cut.isEmpty { return "\(cut) · \(tier.word)" }
        return multipleEditions ? "Standard · \(tier.word)" : nil
    }
}

extension QualityTier {
    /// `HD` / `4K`.
    public var word: String { self == .hd ? "HD" : "4K" }
}
