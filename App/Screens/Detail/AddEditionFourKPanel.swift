import SwiftUI
import FusionhaKit

/// Add a version's "4K availability": a quick look at the indexers before a
/// 4K version is added. Shown while 4K is one of the tiers ticked.
struct AddEditionFourKPanel: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    @Binding var fourK: FourKCheck?
    @State private var checking = false

    var body: some View {
        Section {
            if let fourK {
                let found = fourK.foundUhd == true
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fourK.message ?? (found ? "4K releases are available." : "No 4K releases found yet."))
                            .foregroundStyle(Theme.txt)
                        if let best = fourK.bestReleaseName {
                            Text(best).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                    }
                } icon: {
                    Image(systemName: found ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(found ? Theme.done : Theme.miss)
                }
                .transition(.opacity)
            }
            Button {
                Task { await run() }
            } label: {
                HStack {
                    Label("Check indexers for 4K", systemImage: "magnifyingglass")
                    Spacer()
                    if checking { ProgressView() }
                }
            }
            .disabled(checking)
        } header: {
            Text("4K availability")
        } footer: {
            Text(detail.isSeries
                 ? "A quick look at whether 4K releases of this show exist before you add the version."
                 : "A quick look at whether 4K releases of this movie exist before you add the version.")
        }
    }

    private func run() async {
        guard let client = store.client else { return }
        checking = true
        defer { checking = false }
        do {
            let result = try await client.checkFourK(itemId: detail.id)
            withAnimation(DetailMotion.quick) { fourK = result }
        } catch {
            store.show("Couldn't check for 4K releases", variant: .error)
        }
    }
}
