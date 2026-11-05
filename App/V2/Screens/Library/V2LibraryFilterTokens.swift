import SwiftUI
import FusionhaKit

/// F1's active filters as removable tokens under the filter row (mock
/// filters-alt.js `chip sel`: accent-tinted glass), then a dimmed Clear.
/// Nothing at all when no filter is set, so the page at rest stays one row.
struct V2LibraryFilterTokens: View {
    let filters: V2LibraryFilters
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        let tokens = filters.tokens
        if !tokens.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 7) {
                    HStack(spacing: 7) {
                        ForEach(tokens) { token in tokenButton(token) }
                        Button("Clear") { withAnimation(motion ? .snappy : nil) { filters.reset() } }
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .contentShape(Capsule())
                            .buttonStyle(.plain)
                            .glassControl()
                            .opacity(0.75)
                    }
                }
            }
            .scrollClipDisabled()
            .transition(.opacity)
        }
    }

    private func tokenButton(_ token: V2LibraryToken) -> some View {
        Button {
            withAnimation(motion ? .snappy : nil) { filters.remove(token) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: token.systemImage).font(.system(size: 15, weight: .semibold))
                Text(token.label).font(.system(size: 13.5, weight: .semibold))
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).opacity(0.8)
            }
            .foregroundStyle(Theme.onAccent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 13)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.primary).interactive(), in: Capsule())
        .accessibilityLabel("\(token.label), remove")
    }
}
