import SwiftUI

// Sign-in's v2 form pieces (look pass family 6, mock look-b.js `signin`):
// the fields as one inset-grouped card with the labels on the left, the
// accent Sign in capsule (quiet until both fields are filled), and glass
// capsules for the server line and Explore the demo. The backdrop, the
// Living logo and every step's logic stay v1's. The stage is always dark,
// so the card is white on the dark ground in every palette, as v1's
// panel pieces are.

/// The fields of one step. v1: they stack as they are; v2: one card.
struct LoginFieldGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if ProductLook.isV2 {
            VStack(spacing: 0) { content }
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .padding(.bottom, 14)
        } else {
            VStack(spacing: 0) { content }
        }
    }
}

/// The hairline between two grouped fields (nothing in v1).
struct LoginGroupDivider: View {
    var body: some View {
        if ProductLook.isV2 {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5).padding(.leading, 16)
        }
    }
}

/// A grouped field row: the label on the left, the input filling the rest.
struct LoginFieldRowV2<Input: View>: View {
    let label: String
    let input: Input
    let focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(focused ? Theme.txt : Theme.txt.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 96, alignment: .leading)
            input
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .tint(Theme.txt)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// The step's primary: the accent capsule, dimmed until it can go.
struct AccentSubmit: View {
    let title: String
    var workingTitle: String?
    let working: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if working, let workingTitle {
                    Text(workingTitle)
                } else if working {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.onAccent.opacity(enabled || working ? 1 : 0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.primary.opacity(enabled || working ? 1 : 0.45), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .padding(.top, 2)
        .disabled(!enabled || working)
    }
}

extension View {
    /// v2's glass capsule for a sign-in control (the server line, the demo).
    func loginGlassCapsule(height: CGFloat) -> some View {
        self
            .frame(minHeight: height)
            .contentShape(Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
    }
}
