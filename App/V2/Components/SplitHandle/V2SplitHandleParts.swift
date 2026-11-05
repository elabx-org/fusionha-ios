import SwiftUI

/// The split handle's pill: clear Liquid Glass with a white tint, a hairline
/// and a soft shadow so it reads on light and dark pages alike. It grows
/// and brightens while held (instantly under Reduce Motion).
struct V2SplitGrip: View {
    let held: Bool
    let motion: Bool

    var body: some View {
        Color.clear
            .frame(width: 7, height: held ? 86 : 66)
            .glassEffect(.regular.tint(.white.opacity(held ? 0.9 : 0.5)), in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(Theme.isLight ? 0.35 : 0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .scaleEffect(x: held ? 1.35 : 1, y: 1)
            .animation(motion ? .easeOut(duration: 0.18) : nil, value: held)
    }
}

/// "Close" and "Full width" while dragging: dark glass with white text, so
/// it reads over the dimmed title and over Daylight's light pages.
struct V2SplitLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.footnote.weight(.bold))
            }
            Text(title)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.black.opacity(0.45)), in: Capsule())
        .environment(\.colorScheme, .dark)
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The first-time tip beside the handle.
struct V2SplitTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Drag to resize").font(.subheadline.weight(.semibold))
            Text("or drag right to close").font(.footnote)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .fixedSize()
        .glassEffect(.regular.tint(.black.opacity(0.55)),
                     in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
