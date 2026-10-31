import SwiftUI

// MARK: - Content reserves the downloads pill's space (D3)
//
// The downloads bar is the tab view's bottom accessory. Where it floats over a
// tab's content (above the tab bar, or along the bottom beside the Duo's
// vertical bar) it covered the last row. The owner chose that content makes
// room: while the pill shows, every tab's root gets a bottom safe-area inset
// as tall as the part of the pill that overlaps the tab's own safe area, plus
// a little spacing, so every ScrollView and List in the tab scrolls clear of
// it. Where the system already insets for the accessory the overlap is zero
// and nothing is added; with the pill hidden nothing is added either.

/// The pill's on-screen frame while it shows, published by the accessory to
/// the tabs' roots (`TabRoot`).
@Observable
final class DownloadsPillSpace {
    /// Whether the shell has the pill enabled (iOS 26.1+, queue busy, …).
    var shown = false
    /// The expanded pill's top, in global coordinates.
    var top: CGFloat?
    /// The expanded pill's height.
    var height: CGFloat = 0
    /// The tab bar is minimised and the pill sits inline beside it.
    var inline = false

    /// The gap kept between the last row and the pill.
    static let spacing: CGFloat = 8

    /// The inset a tab whose safe area ends at `safeBottom` (global) needs to
    /// clear the pill: the overlap plus spacing, zero when the pill isn't
    /// over the tab's content. Capped at the pill's own height (plus room for
    /// its gap to the tab bar) in case the two frames disagree on coordinates.
    func reserve(safeBottom: CGFloat?) -> CGFloat {
        guard shown, let top, let safeBottom, height > 0 else { return 0 }
        let overlap = safeBottom - top
        guard overlap > 1 else { return 0 }
        return min(overlap + Self.spacing, height + 3 * Self.spacing)
    }
}

extension View {
    /// Reserves room at the bottom of a tab's root for the downloads pill
    /// while it floats over the tab's content.
    func reservesDownloadsPillSpace() -> some View {
        modifier(DownloadsPillReserver())
    }

    /// Publishes the accessory's frame (expanded only) and placement.
    func publishesDownloadsPillFrame(inline: Bool) -> some View {
        modifier(DownloadsPillFrameWriter(inline: inline))
    }
}

private struct DownloadsPillReserver: ViewModifier {
    @Environment(DownloadsPillSpace.self) private var space: DownloadsPillSpace?
    @Environment(\.motionEnabled) private var motion
    /// The bottom of this tab's safe area without the reserve (global).
    @State private var safeBottom: CGFloat?
    @State private var reserve: CGFloat = 0

    private var target: CGFloat { space?.reserve(safeBottom: safeBottom) ?? 0 }
    private var inline: Bool { space?.inline == true }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: reserve)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Measured outside the inset, so the reserve never feeds back into
            // its own measurement.
            .background {
                Color.clear.onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).maxY
                } action: { bottom in
                    if safeBottom != bottom { safeBottom = bottom }
                }
            }
            // Held while the tab bar is minimised (the pill inline beside it),
            // so the content doesn't jump mid-scroll; dropped as soon as the
            // pill goes.
            .onChange(of: ReserveKey(target: target, inline: inline), initial: true) { _, key in
                guard !key.inline || key.target == 0 || reserve == 0 else { return }
                guard reserve != key.target else { return }
                withAnimation(motion ? .smooth(duration: 0.3) : nil) { reserve = key.target }
            }
    }

    private struct ReserveKey: Equatable {
        let target: CGFloat
        let inline: Bool
    }
}

private struct DownloadsPillFrameWriter: ViewModifier {
    @Environment(DownloadsPillSpace.self) private var space: DownloadsPillSpace?
    let inline: Bool

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                guard let space, !inline else { return }
                if space.top != frame.minY { space.top = frame.minY }
                if space.height != frame.height { space.height = frame.height }
            }
            .onChange(of: inline, initial: true) { _, value in
                if space?.inline != value { space?.inline = value }
            }
    }
}
