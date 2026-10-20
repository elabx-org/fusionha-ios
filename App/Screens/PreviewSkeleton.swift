import SwiftUI
import FusionhaKit

struct PreviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverShimmer(radius: 0).frame(height: 430)
            DiscoverShimmer().frame(width: 220, height: 26).padding(.horizontal, 16)
            DiscoverShimmer().frame(width: 160, height: 12).padding(.horizontal, 16)
            DiscoverShimmer().frame(height: 60).padding(.horizontal, 16)
            Spacer()
        }
    }
}
