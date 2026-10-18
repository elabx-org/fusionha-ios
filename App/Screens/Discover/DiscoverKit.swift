import SwiftUI
import UIKit
import WebKit
import FusionhaKit

// The web primitives Discover, Preview, Requests, Issues and You are built
// from (SegmentedControl, Tabs, Button, PosterStatusBadge, StatusWash, EmptyState,
// Toast), sized 1:1 from their CSS.

enum DiscoverPalette {
    /// The hard-coded search/segment well in Discover's CSS.
    static var well: Color { Theme.bg }
    /// `color-mix(--i2 45%, --txt)`: the active segment text.
    static var activeText: Color { Theme.txt }
    static let activeRing = Color.clear
    static let tmdb = Color(hex: 0x01B4E4)
    static let tvdb = Color(hex: 0x4FB862)
}

// MARK: DiscoverMotion

/// The web's motion rules: the prototype ease, and "reduced" when the OS asks
/// for it or the server's `animations_enabled` setting is off.
enum DiscoverMotion {
    /// `REVEAL_EASE` = cubic-bezier(0.52, 0.01, 0.16, 1).
    static func reveal(_ duration: Double = 0.45) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }

    /// The flyout / sheet ease, cubic-bezier(.32, .72, 0, 1).
    static func flyout(_ duration: Double = 0.44) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: duration)
    }

    @MainActor
    static func reduced(_ osReduceMotion: Bool) -> Bool {
        osReduceMotion || !DiscoverSession.shared.animationsEnabled
    }
}

/// Press feedback for poster cards: the web's hover lift becomes a press dip.
struct DiscoverPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let reduced = DiscoverMotion.reduced(osReduceMotion)
        configuration.label
            .scaleEffect(configuration.isPressed && !reduced ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(reduced ? nil : .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.22), value: configuration.isPressed)
    }
}

/// `Skeleton`: a soft tint with a 1.4s shimmer sweep (static when reduced).
struct DiscoverShimmer: View {
    var radius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.txt.opacity(0.06))
            .overlay {
                if !DiscoverMotion.reduced(osReduceMotion) {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.09), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width)
                            .offset(x: phase * geo.size.width)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
                    }
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: SegmentedControl (sm / md)

struct DiscoverSegmented<Value: Hashable>: View {
    enum Size { case sm, md }
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    let options: [(Value, String)]
    @Binding var selection: Value
    var size: Size = .sm
    /// Inside a flex-column panel the track stretches; segments stay left-aligned.
    var fullTrack = false

    var body: some View {
        HStack(spacing: size == .md ? 4 : 3) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let selected = value == selection
                Button {
                    withAnimation(DiscoverMotion.reduced(osReduceMotion) ? nil : .snappy(duration: 0.22)) { selection = value }
                } label: {
                    Text(options[index].1)
                        .font(.system(size: size == .md ? 15 : 13, weight: .semibold))
                        .foregroundStyle(selected ? DiscoverPalette.activeText : Theme.mut)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, size == .md ? 16 : 11)
                        .padding(.vertical, size == .md ? 9 : 7)
                        .background {
                            if selected {
                                Capsule().fill(Theme.txt.opacity(0.16))
                                    .matchedGeometryEffect(id: "seg", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .id(value)
            }
            if fullTrack { Spacer(minLength: 0) }
        }
        .padding(size == .md ? 4 : 3)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: Tabs

struct DiscoverTabs<Value: Hashable>: View {
    let options: [(Value, String, Int?)]
    @Binding var selection: Value
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let selected = value == selection
                Button {
                    withAnimation(DiscoverMotion.reduced(osReduceMotion) ? nil : .snappy(duration: 0.22)) { selection = value }
                } label: {
                    HStack(spacing: 7) {
                        Text(options[index].1)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? Theme.onInk : Theme.mut)
                        if let badge = options[index].2, badge > 0 {
                            Text("\(badge)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.bg)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Theme.grab, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background {
                        if selected {
                            Capsule().fill(Theme.txt)
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: Button

enum DiscoverButtonKind { case primary, subtle, danger, ghost }

/// Capsules: cream for primary, glass for subtle and danger (danger tints the
/// text), plain for ghost.
struct DiscoverButtonStyle: ButtonStyle {
    var kind: DiscoverButtonKind = .subtle
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 13, weight: kind == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: !fullWidth, vertical: false)
            .padding(.horizontal, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 32)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .contentShape(Capsule())
        switch kind {
        case .primary: label.background(Theme.primary, in: Capsule())
        case .ghost: label
        case .subtle, .danger: label.glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .danger: return Theme.danger
        case .subtle, .ghost: return Theme.txt
        }
    }
}

extension ButtonStyle where Self == DiscoverButtonStyle {
    static func discover(_ kind: DiscoverButtonKind, fullWidth: Bool = false) -> DiscoverButtonStyle {
        DiscoverButtonStyle(kind: kind, fullWidth: fullWidth)
    }
}

/// A 32pt round glass icon button (trash on request/issue rows).
struct DiscoverIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Theme.mut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint == Theme.mut ? Theme.txt : tint)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}
