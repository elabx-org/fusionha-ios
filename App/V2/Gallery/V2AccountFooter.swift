import SwiftUI

/// v2's extra rows at the foot of Account (and the requester's You tab):
/// the Badge gallery, so the owner can check the A1/T5 badges and rails on
/// the device in every palette. In Release builds too (Feather installs
/// Release IPAs). Compiled into v2 only; `AccountView` shows it under `#if V2`.
struct V2AccountFooter: View {
    @State private var showingGallery = false

    var body: some View {
        AccountSectionHeading("fusionha v2")
        Section {
            Button {
                showingGallery = true
            } label: {
                HStack {
                    Text("Badge gallery").font(.body.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.txt)
            .accessibilityHint("Every badge and rail state in every palette")
            .sheet(isPresented: $showingGallery) { BadgeGallerySheet() }
        }
        .listRowBackground(AccountStyle.cell)
    }
}

/// The gallery in its own sheet, with Done.
struct BadgeGallerySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BadgeGalleryView()
                .navigationTitle("Badge gallery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        SheetDoneButton(escapeCloses: true) { dismiss() }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}
