import SwiftUI
import FusionhaKit

/// Interactive ("Manual") search over a v2 title (mock browse-sheets.js
/// `isSheet`): "Manual search" with the scoped heading under it, Close and
/// Refresh, around `V2InteractiveSearchPane`. The model is v1's, parked in
/// the store across a fold / unfold like v1's sheet.
struct V2InteractiveSearchSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: InteractiveTarget
    @State private var model: InteractiveSearchModel?
    private static let modelKey = "search.model"

    var body: some View {
        NavigationStack {
            Group {
                if let model { V2InteractiveSearchPane(model: model) } else { Color.clear }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Manual search").font(.system(size: 16, weight: .bold))
                        Text(model?.heading ?? target.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
                if let model {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                            .disabled(model.inFlight.contains(model.editionId))
                            .accessibilityLabel("Refresh \(model.edition?.label ?? "search") results")
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            guard model == nil else { return }
            let parked = store.drafts.value(Self.modelKey, as: InteractiveSearchModel.self)
            model = parked?.target.id == target.id ? parked : InteractiveSearchModel(store: store, target: target)
        }
        .onDisappear { if let model { store.drafts.save(model, for: Self.modelKey) } }
    }
}
