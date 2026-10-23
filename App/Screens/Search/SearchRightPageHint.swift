import SwiftUI

/// The Spread's right page on Search while no result is open: the kind
/// filter, then where the preview will appear, with the providers asked.
struct SearchRightPageHint: View {
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            SearchKindPicker()
                .padding(.horizontal, Theme.pageGutter)
                .padding(.top, 12)
            hint.frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        // The right page swings open from the fold (Duo motion): a slight
        // settle from the leading edge, a crossfade under Reduce Motion.
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown || !motion ? 1 : 0.97, anchor: .leading)
        .onAppear {
            withAnimation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2)) { shown = true }
        }
    }

    private var hint: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                TmdbLogo(size: 12, label: "TMDB")
                TvdbLogo(size: 15, label: "TheTVDB")
            }
            Text("Pick a result")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Text("Its preview opens here, with its versions, the metadata and Add.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
