import SwiftUI
import FusionhaKit

/// Rename files in v2's form sheet (Look Pass family 1): the same Current /
/// Proposed paths, grouped on one card per version ("HD-1080p · 3 files"),
/// then the files fusionha won't move under an orange "can't be renamed"
/// label with their Wanted path and reason. Paths stay mono and selectable.
struct V2RenameList: View {
    let movable: [RenamePreviewRow]
    let blocked: [RenamePreviewRow]
    let editions: [DetailEdition]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groups(movable), id: \.key) { group in
                V2FormSection(label: group.label) {
                    rows(group.rows, toTag: "Proposed", blocked: false)
                }
            }
            if !blocked.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label(RenameCopy.blockedHeading(blocked.count), systemImage: "exclamationmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.missText)
                        .padding(.horizontal, 4)
                    Text("fusionha never overwrites a file it owns, so these are left where they are.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                    V2FormCard { rows(blocked, toTag: "Wanted", blocked: true) }
                }
            }
        }
    }

    private func rows(_ rows: [RenamePreviewRow], toTag: String, blocked: Bool) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            if index > 0 { V2FormDivider() }
            VStack(alignment: .leading, spacing: 10) {
                line("Current", row.from, color: Theme.mut)
                line(toTag, row.to, color: blocked ? Theme.txt : Theme.doneText)
                if blocked {
                    Label(RenameCopy.blockReason(row), systemImage: "exclamationmark")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.missText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .v2FormRow()
        }
    }

    private func line(_ tag: String, _ path: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(tag)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 72, alignment: .leading)
            V2FormPath(path: path, color: color)
        }
    }

    private struct VersionGroup {
        let key: Int
        let label: String
        let rows: [RenamePreviewRow]
    }

    /// One card per version, in the title's version order; rows without a version last.
    private func groups(_ rows: [RenamePreviewRow]) -> [VersionGroup] {
        var out: [VersionGroup] = []
        for edition in editions {
            let mine = rows.filter { $0.versionId == edition.id }
            if !mine.isEmpty { out.append(VersionGroup(key: edition.id, label: label(edition.label, mine.count), rows: mine)) }
        }
        let known = Set(editions.map(\.id))
        let rest = rows.filter { $0.versionId.map { !known.contains($0) } ?? true }
        if !rest.isEmpty { out.append(VersionGroup(key: -1, label: label(out.isEmpty ? "Files" : "Other files", rest.count), rows: rest)) }
        return out
    }

    private func label(_ name: String, _ count: Int) -> String {
        "\(name) · \(count) file\(count == 1 ? "" : "s")"
    }
}
