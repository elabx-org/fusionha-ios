import SwiftUI
import FusionhaKit

/// Admin only: "Remembered matches" (web `RememberedMatches`): every pick made
/// in a resolve, shared by everyone, each with Forget (asks first).
struct RememberedMatchesView: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    @State private var forgetting: ListMatch?

    var body: some View {
        List {
            Section {
                if store.matches.isEmpty {
                    Text(RememberedCopy.none).foregroundStyle(Theme.mut)
                } else {
                    ForEach(store.matches) { row($0) }
                }
            } footer: {
                Text(RememberedCopy.desc)
            }
            .listRowBackground(AccountStyle.cell)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.i2)
        .navigationTitle(RememberedCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.loadMatches(model.client) }
        .task { await store.loadMatches(model.client) }
        .confirmationDialog(RememberedCopy.ask, isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } }),
                            titleVisibility: .visible, presenting: forgetting) { match in
            Button(RememberedCopy.yes, role: .destructive) { Task { await store.forget(match, model) } }
            Button(RememberedCopy.keep, role: .cancel) {}
        }
    }

    private func row(_ match: ListMatch) -> some View {
        HStack(spacing: 12) {
            ProviderTile(isPlex: match.isPlex, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(RememberedCopy.entry(match)).font(.caption.monospaced()).foregroundStyle(Theme.mut).lineLimit(1)
                Text(RememberedCopy.into(match)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text(RememberedCopy.who(match)).font(.caption).foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 8)
            Button(RememberedCopy.forget, systemImage: "trash", role: .destructive) { forgetting = match }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }
}
