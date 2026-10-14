import SwiftUI

// MARK: - Liquid Glass controls (redesign)
//
// Every floating or page-level control is glass; content (posters, cards,
// rows) never is. Controls are 36pt tall, capsule-shaped, cream text on glass,
// and an "on" state is a brighter cream wash, never a colour: colour belongs
// to status.

extension View {
    /// Interactive glass in a capsule, optionally lit for an "on" state.
    func glassControl(on: Bool = false) -> some View {
        glassEffect(on ? .regular.tint(Theme.txt.opacity(0.16)).interactive() : .regular.interactive(),
                    in: Capsule())
    }
}

/// A 36pt round glass button holding one SF Symbol, with an optional
/// attention dot (the mock's `.g36`).
struct GlassIconButton: View {
    let systemName: String
    let label: String
    var on = false
    var dot: Color?
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.47, weight: .medium))
                .foregroundStyle(Theme.txt)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassControl(on: on)
        .overlay(alignment: .topTrailing) {
            if let dot {
                PulsingDot(color: dot, size: 9, ring: Theme.bg)
                    .offset(x: 1, y: -1)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(label)
    }
}

/// The label of a glass menu button: text plus a chevron (the mock's `.kmenu`).
struct GlassMenuLabel: View {
    let title: String
    var on = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.mut)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(height: 36)
        .contentShape(Capsule())
        .glassControl(on: on)
    }
}
