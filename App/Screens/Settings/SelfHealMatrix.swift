import SwiftUI
import FusionhaKit

/// File Management › Self-heal's 3×2 switch grid (web `shGrid`): one row per
/// kind, columns "Clean up dead links" and "Search after loss". Every switch
/// is off by default and saves its own `auto_*_{kind}` key.
enum SelfHealMatrix {
    struct Kind: Identifiable {
        let id: String
        let label: String
        let icon: String
        let tint: Color
    }

    static var kinds: [Kind] {
        [Kind(id: "movie", label: "Movies", icon: "film", tint: Theme.kind(LibraryKind.movie)),
         Kind(id: "series", label: "Series", icon: "tv", tint: Theme.kind(LibraryKind.series)),
         Kind(id: "anime", label: "Anime", icon: "sparkles", tint: Theme.kind(LibraryKind.anime))]
    }

    static let columnWidth: CGFloat = 92
}

/// The column heads, aligned over the switches.
struct SelfHealMatrixHeader: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 0)
            head("Clean up dead links")
            head("Search after loss")
        }
        .accessibilityHidden(true)
    }

    private func head(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(width: SelfHealMatrix.columnWidth)
    }
}

/// One kind's row: the kind and its two switches.
struct SelfHealMatrixRow: View {
    @Environment(SettingsStore.self) private var store
    let kind: SelfHealMatrix.Kind

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(kind.tint)
                    .frame(width: 26, height: 26)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                Text(kind.label)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
            }
            Spacer(minLength: 0)
            cell(key: "auto_cleanup_dead_links_\(kind.id)", label: "Clean up dead links — \(kind.label)")
            cell(key: "auto_search_after_loss_\(kind.id)", label: "Search after loss — \(kind.label)")
        }
    }

    private func cell(key: String, label: String) -> some View {
        Toggle(label, isOn: store.boolBinding(key))
            .labelsHidden()
            .tint(Theme.indigo)
            .accessibilityLabel(label)
            .frame(width: SelfHealMatrix.columnWidth)
    }
}
