import Foundation
import FusionhaKit

/// What Add a version's Edition menu offers besides Standard and Custom…:
/// the cuts from Settings → Movie Editions, and names typed by hand on other
/// titles of the same kind (owner, IMG_8010: "Encore" should be pickable again).
enum AddEditionVocabulary {
    /// Hand-typed edition names already on the library's titles of `kind`,
    /// leaving out Standard and anything the Settings cuts already offer.
    static func usedNames(in library: [MediaItem], kind: MediaKind, excluding presets: [String]) -> [String] {
        let taken = Set((presets + ["Standard"]).map { $0.lowercased() })
        var seen = Set<String>()
        var names: [String] = []
        for item in library where item.kind == kind {
            for edition in item.editions {
                guard let raw = edition.movieEdition?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { continue }
                let key = raw.lowercased()
                guard !taken.contains(key), seen.insert(key).inserted else { continue }
                names.append(raw)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
