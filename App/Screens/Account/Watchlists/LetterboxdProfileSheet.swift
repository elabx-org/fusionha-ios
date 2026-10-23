import SwiftUI
import FusionhaKit

/// "Your Letterboxd" (web `ProfilePane` as a sheet): connect, change or
/// disconnect the username. Opened from the Letterboxd group's Change and from
/// the not-connected Diary row; a good connect closes it.
struct LetterboxdProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: WatchlistsStore

    var body: some View {
        NavigationStack {
            Form {
                if let read = store.letterboxd {
                    Section {
                        LetterboxdProfileRows(store: store, read: read) { dismiss() }
                    } footer: {
                        Text("Public data only")
                    }
                    .listRowBackground(AccountStyle.cell)
                } else {
                    Text(AutomaticRequestsCopy.loading).foregroundStyle(Theme.mut)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.i2)
            .navigationTitle("Your Letterboxd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton(title: "Close") { dismiss() } }
            }
            .closeOnlyBars()
        }
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, 24) }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }
}
