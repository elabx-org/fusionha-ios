import SwiftUI
import FusionhaKit

/// One import list (web `ImportListRow`): the provider tile, the name, the
/// kind and tier chips, "MDBList · every 6 h · last sync added 3 · 2 hr ago",
/// one status pill, the Enabled switch, Sync now / Edit / Delete, and its
/// notes (unmatched titles with Review, the last error).
struct ImportListRow: View {
    @Environment(AppModel.self) private var model
    let store: ImportListsStore
    let list: ImportList
    let onEdit: () -> Void
    let onReview: () -> Void
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ProviderTile(provider: list.site)
                VStack(alignment: .leading, spacing: 5) {
                    Text(list.name).font(.body.weight(.semibold)).foregroundStyle(Theme.txt).lineLimit(2)
                    chips
                    Text(ImportListCopy.meta(list)).font(.caption).foregroundStyle(Theme.mut)
                    ImportListStatusPill(look: ImportListCopy.status(list))
                }
                Spacer(minLength: 4)
                Toggle("Enable \(list.name)", isOn: Binding(get: { list.enabled }, set: { on in
                    Task { await store.setEnabled(list, on, model) }
                }))
                .labelsHidden()
                .disabled(store.busy.contains(list.id))
            }
            notes
            actions
        }
        .padding(.vertical, 4)
        .confirmationDialog(ImportListCopy.deleteAsk(list.name), isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete list", role: .destructive) { Task { await store.delete(list, model) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(ImportListCopy.deleteDesc)
        }
    }

    private var chips: some View {
        HStack(spacing: 5) {
            Text(ImportListCopy.kindWord(list.mediaKind.rawValue))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kindColor)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(EditionChipBackground(color: kindColor, radius: 5))
            ForEach(list.versions, id: \.tier) { TierPill(tier: $0.tier, large: true) }
        }
    }

    private var kindColor: Color {
        switch list.mediaKind {
        case .movie: return Theme.kindMovie
        case .series: return Theme.kindSeries
        case .anime: return Theme.kindAnime
        }
    }

    @ViewBuilder private var notes: some View {
        if list.unmatchedCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle").foregroundStyle(Theme.missText)
                Text(ImportListCopy.unmatched(list.unmatchedCount)).font(.footnote).foregroundStyle(Theme.txt)
                Spacer(minLength: 4)
                Button("Review", action: onReview).buttonStyle(.web()).font(.footnote)
            }
        }
        if let error = list.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(Theme.missText)
        }
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Button("Sync now", systemImage: "arrow.clockwise") { Task { await store.sync(list, model) } }
                .disabled(store.busy.contains(list.id))
            Button("Edit", systemImage: "pencil", action: onEdit)
            Spacer(minLength: 0)
            Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .font(.subheadline)
    }
}

/// A status pill: the word in its status's text shade on a quiet wash of it.
struct ImportListStatusPill: View {
    let look: (word: String, tone: MonoToken?)

    var body: some View {
        let color = look.tone?.color ?? Theme.dim
        Text(look.word)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.text(look.tone))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}
