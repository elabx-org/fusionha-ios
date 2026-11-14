import SwiftUI
import FusionhaKit

extension View {
    /// CI screenshots only: renders the app inside a fixed iPhone Duo frame
    /// with a fake fold (`DuoHarness`). Compiled out of release builds, where
    /// it returns the view unchanged. `backdrop` false leaves the iPad around
    /// the frame clear (a full-screen cover over the framed app, S3).
    @ViewBuilder
    func duoHarness(backdrop: Bool = true) -> some View {
        #if DEBUG
        if let frame = DuoHarness.frame {
            modifier(DuoHarnessFrame(frame: frame, backdrop: backdrop))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if DEBUG
/// The Duo screenshot harness. CI cannot fold an iPhone Duo (its poses are
/// Device Hub buttons the hosted runner can't press), so the screenshots job
/// renders the app on a large iPad simulator inside a frame the size of a
/// Duo display, with the display's safe area and, open in landscape, a flat
/// (inactive, zero-wide) fold at the device kit's x. `FoldInfo` reads that
/// fold instead of the reserved regions, so every fold-aware layout (the
/// shell's Spread, the Board, the month grid…) lays out as on a Duo.
///
///   FUSIONHA_SCREENSHOT_DUO_FRAME=open|portrait|folded
///   FUSIONHA_SCREENSHOT_DUO_LAYOUT=spread|web   (the "iPhone Duo, open" setting)
///   FUSIONHA_SCREENSHOT_DUO_POSE=flat|book|tabletop (an inactive or an active fold;
///                                               tabletop = an active side-to-side fold, portrait frame only)
///   FUSIONHA_SCREENSHOT_DUO_LIST=shown|hidden   (the sidebar button, every tab)
///
/// Only read in DEBUG builds; the release app has no harness.
enum DuoHarness {
    /// The window's width: the harness centres its frame in it.
    private static let screenWidth: CGFloat = MainActor.assumeIsolated {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 1032
    }

    /// The window's height: the harness centres its frame in it.
    private static let screenHeight: CGFloat = MainActor.assumeIsolated {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 1376
    }

    enum Frame: String {
        /// Inner display, landscape: 951 x 669, the fold top to bottom.
        case open
        /// Inner display, portrait: 669 x 951, the fold side to side.
        case portrait
        /// Outer display: 466 x 678, no fold.
        case folded

        var size: CGSize {
            switch self {
            case .open: CGSize(width: 951, height: 669)
            case .portrait: CGSize(width: 669, height: 951)
            case .folded: CGSize(width: 466, height: 678)
            }
        }

        /// The device kit's safe areas (duo-designer `device.css`): asymmetric,
        /// the system column on the right.
        var insets: EdgeInsets {
            switch self {
            case .open: EdgeInsets(top: 22, leading: 24, bottom: 22, trailing: 78)
            case .portrait: EdgeInsets(top: 68, leading: 24, bottom: 26, trailing: 24)
            case .folded: EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 86)
            }
        }

        /// The fold's centre line in the frame (the display's middle; the
        /// content is off-centre because of the right-hand column).
        var verticalFoldX: CGFloat? { self == .open ? 475.5 : nil }
        var horizontalFoldY: CGFloat? { self == .portrait ? 475.5 : nil }

        var cornerRadius: CGFloat { self == .folded ? 46 : 40 }
    }

    /// The frame on screen: the launch's, until a refold step changes it
    /// (`FUSIONHA_SCREENSHOT_DUO_REFOLD`). Observable, so the harness frame
    /// and the views that read it follow a step.
    static var frame: Frame? { live.frame }

    @Observable
    final class Live {
        var frame: Frame? = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DUO_FRAME"]
            .flatMap(Frame.init(rawValue:))
    }

    nonisolated(unsafe) static let live = Live()

    /// `FUSIONHA_SCREENSHOT_DUO_POSE=book`: the fake fold is active (partially
    /// folded, reserved); otherwise flat (inactive, nothing reserved).
    static let bookPose = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DUO_POSE"] == "book"

    /// `FUSIONHA_SCREENSHOT_DUO_POSE=tabletop` with the portrait frame: the fake
    /// fold is an active, side-to-side one (half folded on a table). Without it
    /// portrait stays flat, with no fold.
    static let tabletopPose = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DUO_POSE"] == "tabletop"

    /// `FUSIONHA_SCREENSHOT_DUO_LIST=hidden`: every tab's list hidden (the sidebar button).
    static let listHidden = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DUO_LIST"] == "hidden"

    /// Applies the harness's launch settings before the first view reads them.
    static func prepare() {
        let env = ProcessInfo.processInfo.environment
        if let steps = env["FUSIONHA_SCREENSHOT_DUO_REFOLD"] { refold(steps) }
        if let layout = env["FUSIONHA_SCREENSHOT_DUO_LAYOUT"].flatMap(DuoOpenLayout.init(rawValue:)) {
            UserDefaults.standard.set(layout.rawValue, forKey: DuoOpenLayout.storageKey)
        }
        if env["FUSIONHA_SCREENSHOT_DUO_LIST"] != nil {
            UserDefaults.standard.set(listHidden ? "library,discover,search,calendar,activity,requests,you" : "",
                                      forKey: DuoListMemory.storageKey)
        }
    }

    /// Fold continuity shots: `FUSIONHA_SCREENSHOT_DUO_REFOLD=open@16,folded@26`
    /// switches the frame to `open` 16 s after launch, then back to `folded`
    /// at 26 s, in the same process (a fold is a resize; the app keeps its
    /// scene), so the shots before and after each step show what it kept.
    private static func refold(_ steps: String) {
        let parsed: [(Frame, Double)] = steps.split(separator: ",").compactMap { step in
            let parts = step.split(separator: "@")
            guard parts.count == 2, let frame = Frame(rawValue: String(parts[0])), let at = Double(parts[1]) else { return nil }
            return (frame, at)
        }
        Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            for (frame, at) in parsed {
                try? await clock.sleep(until: start.advanced(by: .milliseconds(Int(at * 1000))))
                live.frame = frame
            }
        }
    }

    /// The fake fold in a container's own coordinates, like
    /// `reservedRegions(kind: .division, options: .includeInactive)` would
    /// report it flat open. `nil` outside the harness or when the fold
    /// isn't inside the container.
    static func verticalFold(in proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        guard let frame, let x = frame.verticalFoldX else { return nil }
        // Global, not a named space: a named space doesn't reach through the
        // tab view's hosting controllers (it fell back to global, 40 pt off).
        // The frame is centred on the full-screen window.
        let originX = (screenWidth - frame.size.width) / 2
        let local = originX + x - proxy.frame(in: .global).minX
        guard proxy.size.height > 0, local > 0, local < proxy.size.width else { return nil }
        return local...local
    }

    /// The tabletop pose's fake fold (`tabletopPose`, portrait frame): a
    /// zero-height range at the frame's `horizontalFoldY`, in the container's
    /// own coordinates, as `reservedRegions(kind: .division)` would report the
    /// active region. `nil` otherwise, or when the fold isn't inside the container.
    static func horizontalFold(in proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        guard tabletopPose, let frame, let y = frame.horizontalFoldY else { return nil }
        let originY = (screenHeight - frame.size.height) / 2
        let local = originY + y - proxy.frame(in: .global).minY
        guard proxy.size.width > 0, local > 0, local < proxy.size.height else { return nil }
        return local...local
    }
}

/// The frame: centred on the iPad (CI crops the screenshot to it), clipped to
/// the display's corners, with a hairline guide on the fold so a reviewer can
/// see that nothing crosses it.
private struct DuoHarnessFrame: ViewModifier {
    let frame: DuoHarness.Frame
    var backdrop = true

    func body(content: Content) -> some View {
        ZStack {
            (backdrop ? Theme.panel : Color.clear).ignoresSafeArea()
            content
                .safeAreaPadding(frame.insets)
                .environment(\.horizontalSizeClass, frame == .folded ? .compact : .regular)
                .frame(width: frame.size.width, height: frame.size.height)
                .overlay(alignment: .topLeading) { foldGuide }
                .clipShape(RoundedRectangle(cornerRadius: frame.cornerRadius, style: .continuous))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var foldGuide: some View {
        if let x = frame.verticalFoldX {
            // Faint when flat: nothing is reserved there, content may cross it.
            Rectangle()
                .fill(Theme.danger.opacity(DuoHarness.bookPose ? 0.55 : 0.18))
                .frame(width: 1, height: frame.size.height)
                .offset(x: x - 0.5)
                .allowsHitTesting(false)
        } else if let y = frame.horizontalFoldY {
            Rectangle()
                .fill(Theme.danger.opacity(0.55))
                .frame(width: frame.size.width, height: 1)
                .offset(y: y - 0.5)
                .allowsHitTesting(false)
        }
    }
}
#endif
