import SwiftUI
import FusionhaKit

/// Home's title (owner, 2026-11-07, logo option A): the fusionha mark at
/// the capitals' height just before "Home", then the counts line. Drawn
/// in the page at every width; the bar keeps "Home" only for the back
/// button and VoiceOver (`V2HomeView`).
struct V2HomeHeading<Stats: View>: View {
    let stats: Stats
    @Environment(\.pagePalette) private var page
    @ScaledMetric(relativeTo: .largeTitle) private var mark: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: mark / 3) {
                Image("BrandLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: mark, height: mark)
                    .accessibilityHidden(true)
                Text("Home")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .accessibilityAddTraits(.isHeader)
            }
            stats
        }
    }
}
