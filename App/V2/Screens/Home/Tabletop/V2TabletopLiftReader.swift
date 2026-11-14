import SwiftUI

/// Hands its content the lift's progress frame by frame: `progress` is
/// animatable, so setting it inside `withAnimation` re-draws the content at
/// every value on the way (`V2HomeTabletop`'s one progress value).
struct V2TabletopLiftReader<Content: View>: View, Animatable {
    var progress: Double
    @ViewBuilder let content: (Double) -> Content

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        content(min(max(progress, 0), 1))
    }
}
