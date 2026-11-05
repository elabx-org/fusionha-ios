import SwiftUI

/// v2's extra rows at the foot of Account (and the requester's You tab):
/// the Badge gallery and the Ground preview, so the owner can check the
/// A1/T5 badges, rails, grounds and cards on the device in every palette.
/// In Release builds too (Feather installs Release IPAs). Compiled into v2 only; `AccountView` shows it under `#if V2`.
struct V2AccountFooter: View {
    @State private var showingGallery = false
    @State private var showingGround = false

    var body: some View {
        AccountSectionHeading("fusionha v2")
        Section {
            row("Badge gallery", hint: "Every badge and rail state in every palette") { showingGallery = true }
                .sheet(isPresented: $showingGallery) { BadgeGallerySheet() }
            row("Ground preview", hint: "The art palette ground and frosted cards in every palette") { showingGround = true }
                .sheet(isPresented: $showingGround) { GroundPreviewSheet() }
        }
        .listRowBackground(AccountStyle.cell)
    }

    private func row(_ title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.dim)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.txt)
        .accessibilityHint(hint)
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

/// The Ground preview in its own sheet, with Done.
struct GroundPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GroundPreviewView()
                .navigationTitle("Ground preview")
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
