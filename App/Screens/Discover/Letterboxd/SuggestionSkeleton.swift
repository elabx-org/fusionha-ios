import SwiftUI

/// The rail's loading row (web `Skeleton`): six card shapes, a poster and two
/// lines each, shimmering unless motion is reduced.
struct SuggestionSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    DiscoverShimmer(radius: 8)
                        .frame(width: SuggestionCard.width, height: SuggestionCard.width * 1.5)
                    DiscoverShimmer(radius: 6).frame(width: SuggestionCard.width * 0.8, height: 12)
                    DiscoverShimmer(radius: 6).frame(width: SuggestionCard.width * 0.5, height: 12)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Loading suggestions")
    }
}
