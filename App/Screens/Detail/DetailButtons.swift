import SwiftUI

// MARK: - Glass rails

/// An icon button inside a glass rail (`rbtn` / per-edition rail buttons).
struct DetailRailButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var glyph: CGFloat = 18
    var tint: Color = Theme.mut
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    DetailSpinner(size: glyph - 2, color: Theme.mut)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: glyph, weight: .regular))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(DetailPressStyle())
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// Press-to-scale `.9` (the web's `:active { transform: scale(.9) }`).
struct DetailPressStyle: ButtonStyle {
    @Environment(\.detailReduceMotion) private var reduce
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduce ? 0.9 : 1)
            .animation(reduce ? nil : DetailMotion.pop, value: configuration.isPressed)
    }
}

/// A round glass action on a card (episode / edition card actions, 40–44pt).
/// The card is content; the button on it is a control, so it is glass.
struct DetailSquareAction: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 44
    var tint: Color = Theme.txt
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy { DetailSpinner(size: 15) } else {
                    Image(systemName: systemImage).font(.system(size: 16)).foregroundStyle(tint)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(DetailPressStyle())
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// The face of a labelled glass capsule control (`.vacts span`): a glyph and
/// a short label, cream on glass, lit when `on`. Used as a Button or Menu label.
struct DetailGlassLabel: View {
    let systemImage: String
    let text: String
    var on = false
    var height: CGFloat = 40
    /// Stretch to the offered width (the opened version's action bar).
    var fill = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .medium))
            Text(text).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(Theme.txt)
        .padding(.horizontal, 14)
        .frame(maxWidth: fill ? .infinity : nil)
        .frame(height: height)
        .contentShape(Capsule())
        .glassControl(on: on)
    }
}
