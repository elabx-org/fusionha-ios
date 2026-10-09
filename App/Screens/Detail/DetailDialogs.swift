import SwiftUI
import FusionhaKit

// The item dialogs the detail page owns share this vocabulary; Delete lives
// here, Edit item and Add a version in EditItemSheet.swift and
// AddEditionSheet.swift. Native Form controls (the web's "no native controls"
// rule is a browser rule), with the web's fields, order and words.

// MARK: - Shared vocabulary

struct VocabOption: Hashable {
    let value: String
    let label: String
    init(_ value: String, _ label: String) {
        self.value = value
        self.label = label
    }
}

enum DetailVocab {
    static let monitorOptions: [VocabOption] = [
        VocabOption("all", "All"), VocabOption("future", "Future"), VocabOption("missing", "Missing"),
        VocabOption("existing", "Existing"), VocabOption("recent", "Recent"), VocabOption("pilot", "Pilot"),
        VocabOption("firstSeason", "First Season"), VocabOption("lastSeason", "Last Season"),
        VocabOption("monitorSpecials", "Monitor Specials"), VocabOption("none", "None"),
    ]
    /// Series type with its numbering hint (`S01E05` / `2020-05-25` / `absolute 005`).
    static let seriesTypes: [VocabOption] = [
        VocabOption("standard", "Standard · S01E05"), VocabOption("daily", "Daily · 2020-05-25"),
        VocabOption("anime", "Anime · absolute 005"),
    ]
    static let minimumAvailability: [VocabOption] = [
        VocabOption("announced", "Announced"), VocabOption("inCinemas", "In Cinemas"), VocabOption("released", "Released"),
    ]
    static let dispositions: [VocabOption] = [
        VocabOption("move", "Move the files to the new folder"),
        VocabOption("leave", "Leave the files where they are"),
        VocabOption("delete", "Delete the existing files"),
    ]

    static func monitorLabel(_ value: String?) -> String {
        monitorOptions.first { $0.value == value }?.label ?? "—"
    }

    /// The profile kinds an item can draw from: its own kind, plus `anime` for
    /// an anime title; legacy kind-less profiles always qualify.
    static func profiles(_ all: [QualityProfile], for detail: ItemDetail, keep: Int? = nil) -> [QualityProfile] {
        var kinds: Set<String> = [detail.kind.rawValue]
        if detail.isAnime == true { kinds.insert("anime") }
        return all.filter { p in p.mediaKind == nil || kinds.contains(p.mediaKind ?? "") || p.id == keep }
    }

    static func profileKind(_ detail: ItemDetail) -> String {
        detail.isAnime == true ? "anime" : detail.kind.rawValue
    }

    static func is4kRoot(_ path: String) -> Bool {
        let p = path.lowercased()
        return p.contains("4k") || p.contains("2160") || p.contains("uhd")
    }

    static func rootMatchesKind(_ path: String, detail: ItemDetail) -> Bool {
        let p = path.lowercased()
        if detail.isAnime == true { return p.contains("anime") }
        switch detail.kind {
        case .movie: return p.contains("movie") || p.contains("film")
        case .series: return p.contains("tv") || p.contains("series") || p.contains("show")
        }
    }

    /// Mirrors the web's `defaultRootId`: kind and tier, then kind, then tier.
    static func defaultRoot(_ tier: QualityTier, detail: ItemDetail, roots: [RootFolder]) -> Int? {
        let wants4k = tier == .uhd
        let kind: (RootFolder) -> Bool = { rootMatchesKind($0.path, detail: detail) }
        let tierMatch: (RootFolder) -> Bool = { is4kRoot($0.path) == wants4k }
        return (roots.first { kind($0) && tierMatch($0) } ?? roots.first(where: kind)
            ?? roots.first(where: tierMatch) ?? roots.first)?.id
    }

    static func defaultProfile(_ tier: QualityTier, profiles: [QualityProfile]) -> Int? {
        let wants4k = tier == .uhd
        let match = profiles.first { p in
            let n = p.name.lowercased()
            let is4k = n.contains("4k") || n.contains("2160") || n.contains("uhd") || n.contains("ultra")
            return is4k == wants4k
        }
        return (match ?? profiles.first)?.id
    }
}

struct DialogFieldLabel: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(Theme.txt)
            if let subtitle {
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            }
        }
    }
}

// MARK: - Delete

struct DeleteItemSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let detail: ItemDetail

    @State private var deleteFiles = false
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 34, height: 34)
                    .background(Theme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                Text("Delete \(detail.title)?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(2)
            }
            Text("This removes the title and all its versions from your library. This cannot be undone.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Also delete the downloaded files from disk", isOn: $deleteFiles)
                .font(.system(size: 14))
                .tint(Theme.danger)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    Task {
                        busy = true
                        let ok = await store.deleteItem(deleteFiles: deleteFiles)
                        busy = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text(busy ? "Deleting…" : "Delete").fontWeight(.bold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.danger)
                .controlSize(.large)
                .disabled(busy)
            }
        }
        .padding(20)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
    }
}
