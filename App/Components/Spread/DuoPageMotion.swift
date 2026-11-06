import SwiftUI

/// The open Duo's right page coming in (the owner's Duo motion brief): it
/// swings open from the fold, hinged on its leading edge, and settles from a
/// slight zoom, on a no-bounce spring of about 0.38 s. The page going out only
/// fades. Under Reduce Motion (or animations off) a short crossfade.
///
/// Render-only effects (rotation, scale, opacity), so the page lays out once
/// and the swing never re-flows the list beside it.
enum DuoPageMotion {
    static let swing = Animation.spring(duration: 0.38, bounce: 0)
    static let fade = Animation.easeInOut(duration: 0.2)

    static func animation(motion: Bool) -> Animation { motion ? swing : fade }

    /// The transition carries its own animation: the shell's split change
    /// itself is not animated on the open Duo.
    /// `flat`: v2's seamless title, with no 3D swing. Under the swing's
    /// perspective the arriving title's page lost the system column and the
    /// display's foot (its own toolbar showed in the page, its colours
    /// stopped short of the column) until the swing ended (owner, build 805).
    static func transition(motion: Bool, flat: Bool = false) -> AnyTransition {
        guard motion else { return .opacity.animation(fade) }
        if flat {
            return .asymmetric(
                insertion: .modifier(active: PageSlide(open: false), identity: PageSlide(open: true)),
                removal: .opacity.animation(.easeOut(duration: 0.16))
            )
            .animation(swing)
        }
        return .asymmetric(
            insertion: .modifier(active: PageSwing(open: false), identity: PageSwing(open: true)),
            removal: .opacity.animation(.easeOut(duration: 0.16))
        )
        .animation(swing)
    }
}

private struct PageSwing: ViewModifier {
    let open: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(open ? 0 : -11), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.55)
            .scaleEffect(open ? 1 : 1.03, anchor: .leading)
            .offset(x: open ? 0 : 18)
            .opacity(open ? 1 : 0)
    }
}

/// v2's page coming in: a short slide and fade, no 3D (`DuoPageMotion.transition(flat:)`).
private struct PageSlide: ViewModifier {
    let open: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: open ? 0 : 18)
            .opacity(open ? 1 : 0)
    }
}
