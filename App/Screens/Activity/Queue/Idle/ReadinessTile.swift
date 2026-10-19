import SwiftUI
import FusionhaKit

extension IdleTime.TileState {
    /// `--sc`: green ok, cyan soon/running, amber warn.
    var color: Color {
        switch self {
        case .ok: return Theme.done
        case .soon, .run: return Theme.grab
        case .warn: return Theme.miss
        }
    }
}

/// One readiness tile (web `ReadinessTile`): an uppercase key with its icon in
/// the state colour over a solid panel tinted by that state.
struct ReadinessTile<Content: View>: View {
    let icon: String
    let label: String
    var state: IdleTime.TileState = .ok
    var compact = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.color)
                    .accessibilityHidden(true)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            content
        }
        .padding(.horizontal, compact ? 11 : 13)
        .padding(.vertical, compact ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .idleCard(tint: state.color, base: Theme.panel2, radius: 12)
        .accessibilityElement(children: .combine)
    }
}

/// The big mono value (`.tv`) with an optional small trailing note.
struct ReadinessValue: View {
    let value: String
    var note: String?
    var compact = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: compact ? 17 : 20, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.txt)
            if let note {
                Text(note).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.top, 6)
    }
}

/// The muted one-line caption under a value (`.ts`).
struct ReadinessCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.top, 3)
    }
}

/// The free-space bar (`.dbar`): a solid fill growing from the left on appear.
struct ReadinessDiskBar: View {
    let fraction: Double
    let color: Color
    @Environment(\.actReduceMotion) private var reduce
    @State private var shown = false

    var body: some View {
        Capsule()
            .fill(Theme.txt.opacity(0.09))
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(color)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                        .scaleEffect(x: shown || reduce ? 1 : 0, anchor: .leading)
                }
            }
            .clipShape(Capsule())
            .padding(.top, 9)
            .onAppear {
                guard !reduce else { return }
                withAnimation(.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.9)) { shown = true }
            }
            .accessibilityHidden(true)
    }
}
