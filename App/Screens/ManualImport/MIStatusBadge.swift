import SwiftUI
import FusionhaKit

/// A row's one status icon and its colour (the web's `MI_STATUS`).
extension ManualImportStatus {
    var symbol: String {
        switch self {
        case .ready: return "checkmark.circle.fill"
        case .upgrade: return "arrow.up.circle.fill"
        case .notUpgrade: return "lessthanorequalto.circle.fill"
        case .downgrade: return "arrow.down.circle.fill"
        case .keep: return "internaldrive.fill"
        case .lowConfidence: return "questionmark.circle.fill"
        case .nameFile: return "notequal.circle.fill"
        case .titleEpisode: return "text.badge.xmark"
        case .noEpisode: return "number.circle.fill"
        case .noMatch: return "xmark.circle.fill"
        case .held: return "exclamationmark.circle.fill"
        case .imported: return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .ready, .upgrade, .imported: return Theme.done
        case .notUpgrade, .lowConfidence, .nameFile, .titleEpisode, .noEpisode, .held: return Theme.miss
        case .downgrade, .noMatch: return Theme.danger
        case .keep: return Theme.dim
        }
    }

    /// What it means (the status key).
    var means: String {
        switch self {
        case .ready: return "Matched, checked and selectable. Imports as shown."
        case .upgrade: return "Replaces the file on disk and beats it."
        case .notUpgrade: return "The same as or worse than the file on disk. Pick which file stays."
        case .downgrade: return "You chose this file: it replaces a better one."
        case .keep: return "Your file on disk stays. This one is skipped."
        case .lowConfidence: return "The match might be the wrong title. Confirm or re-match it."
        case .nameFile: return "The release name and the measured file disagree."
        case .titleEpisode: return "The episode title in the name belongs to another title in your library."
        case .noEpisode: return "Season or episode couldn't be read. Pick it."
        case .noMatch: return "No library title found."
        case .held: return "Waiting on you. Open the row for the reason."
        case .imported: return "Already imported."
        }
    }
}

/// The status icon; a tap shows its full wording.
struct MIStatusBadge: View {
    let row: ManualImportRow
    @State private var showing = false

    var body: some View {
        let status = ManualImportRules.status(row)
        Button { showing = true } label: {
            Image(systemName: status.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(minWidth: 28, minHeight: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ManualImportRules.statusLong(row))
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ManualImportRules.statusLong(row)).font(.subheadline.weight(.semibold))
                Text(status.means).font(.footnote).foregroundStyle(Theme.mut)
            }
            .padding(14)
            .frame(maxWidth: 300, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// The status key (ⓘ in the toolbar).
struct MIStatusKey: View {
    var body: some View {
        NavigationStack {
            List(ManualImportStatus.allCases, id: \.self) { status in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.name).font(.subheadline.weight(.semibold))
                        Text(status.means).font(.footnote).foregroundStyle(Theme.mut)
                    }
                } icon: {
                    Image(systemName: status.symbol).foregroundStyle(status.color)
                }
            }
            .navigationTitle("Status key")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
