import SwiftUI
import FusionhaKit

/// The folded Duo / phone tab bar: a native segmented control (series:
/// Seasons · Files · History · Searches; movie: Files · History · Searches
/// (+ Collection)),
/// with the version menu under four segments and beside three. The
/// Overview rails follow the tab content in the page (`DetailPage`).
struct DetailCompactTabBar: View {
    let detail: ItemDetail
    let tabs: [(DetailTab, String)]
    let current: DetailTab
    let select: (DetailTab) -> Void

    private var showsVersions: Bool { detail.versionsSorted.count > 1 }

    var body: some View {
        // Four segments leave no room beside them: the menu goes under.
        if tabs.count > 3 {
            VStack(alignment: .leading, spacing: 10) {
                picker
                if showsVersions { DetailVersionMenu(detail: detail) }
            }
        } else {
            HStack(spacing: 10) {
                picker
                if showsVersions { DetailVersionMenu(detail: detail) }
            }
        }
    }

    private var picker: some View {
        Picker("Tab", selection: Binding(get: { current }, set: { select($0) })) {
            ForEach(tabs.indices, id: \.self) { index in
                Text(tabs[index].1).tag(tabs[index].0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
