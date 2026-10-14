import SwiftUI
import FusionhaKit

// MARK: - Pieces

/// A labelled input styled like the web login's `.field` + `.input`.
struct LoginField<Input: View>: View {
    let label: String
    @ViewBuilder var input: Input
    var focused: () -> Bool

    var body: some View {
        let isFocused = focused()
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
            input
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .tint(Theme.txt)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Theme.bg.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isFocused ? Theme.txt.opacity(0.6) : Theme.line))
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .padding(.bottom, 14)
    }
}

/// The primary button: house-light cream with a slow sheen crossing it.
struct GradientSubmit: View {
    let title: String
    var workingTitle: String? = nil
    let working: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let shift = (sin(t * .pi / 3) + 1) / 2
                    ZStack {
                        Theme.fusion
                        LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.3),
                                               .init(color: .white.opacity(0.45), location: 0.5),
                                               .init(color: .white.opacity(0), location: 0.7)],
                                       startPoint: UnitPoint(x: -0.6 + 1.2 * shift, y: 0.5),
                                       endPoint: UnitPoint(x: 0.4 + 1.2 * shift, y: 0.5))
                            .blendMode(.softLight)
                    }
                }
                if working, let workingTitle {
                    Text(workingTitle).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onPrimary)
                } else if working {
                    ProgressView().tint(Theme.onPrimary)
                } else {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.onPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .disabled(!enabled || working)
        .opacity(enabled ? 1 : 0.55)
    }
}

struct MethodIcon: View {
    let method: SignInMethod
    var body: some View {
        switch method {
        case .fusionha:
            Image("BrandLogo").resizable().scaledToFit().frame(width: 22, height: 22)
        case .plex:
            Image("plex-mark").resizable().scaledToFit().frame(width: 18, height: 18)
                .foregroundStyle(Theme.plexGold)
        }
    }
}

extension SignInMethod {
    var label: String { self == .fusionha ? "fusionha" : "Plex" }
}

/// One provider: a single "Continue with …" pill.
struct SoloMethodButton: View {
    let method: SignInMethod
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                MethodIcon(method: method)
                Text("Continue with \(method.label)")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(method == .plex ? Color(hex: 0xEDC56E) : Theme.txt)
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl()
    }
}

/// Several providers: the segmented pill with a springy sliding indicator.
struct MethodPill: View {
    let methods: [SignInMethod]
    let selection: SignInMethod?
    let pick: (SignInMethod) -> Void
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(methods, id: \.self) { method in
                Button { pick(method) } label: {
                    HStack(spacing: 9) {
                        MethodIcon(method: method)
                        Text(method.label)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(selection == method ? Theme.txt : Theme.mut)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background {
                        if selection == method {
                            Capsule()
                                .fill(Theme.txt.opacity(0.16))
                                .matchedGeometryEffect(id: "indicator", in: indicator)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: Capsule())
        .animation(.spring(duration: 0.32, bounce: 0.35), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}


/// `nudge`: a small horizontal "no" shake (420ms, after 160ms) for the form
/// after a failed attempt in the Living layout.
struct Nudge: ViewModifier {
    let trigger: Int
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: motion ? trigger : 0) { view, x in
            view.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0, duration: 0.16)
                CubicKeyframe(-7, duration: 0.105)
                CubicKeyframe(5, duration: 0.105)
                CubicKeyframe(-2, duration: 0.105)
                CubicKeyframe(0, duration: 0.105)
            }
        }
    }
}
