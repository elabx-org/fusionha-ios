import SwiftUI
import FusionhaKit

// MARK: - Shared pieces

/// The 36×36 r10 tinted icon tile (`.cico`).
struct TaskIconTile: View {
    let color: Color
    var spinning = false
    var size: CGFloat = 36
    var radius: CGFloat = 10
    var glyph: CGFloat = 18
    let icon: AnyView

    init(color: Color, spinning: Bool = false, size: CGFloat = 36, radius: CGFloat = 10, glyph: CGFloat = 18, @ViewBuilder icon: () -> some View) {
        self.color = color
        self.spinning = spinning
        self.size = size
        self.radius = radius
        self.glyph = glyph
        self.icon = AnyView(icon())
    }

    var body: some View {
        icon
            .font(.system(size: glyph * 0.8, weight: .semibold))
            .frame(width: glyph, height: glyph)
            .actSpin(spinning, duration: 1.1)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The broken-ring spinner glyph.
struct TaskSpinnerGlyph: View {
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-20))
            .padding(1.5)
    }
}

func taskIcon(_ kind: TaskIconKind) -> String {
    switch kind {
    case .search: return "magnifyingglass"
    case .rss: return "dot.radiowaves.up.forward"
    case .refresh: return "arrow.clockwise"
    case .fail: return "exclamationmark.circle"
    }
}

func taskIconColor(_ kind: TaskIconKind) -> Color {
    switch kind {
    case .search: return Theme.grab
    case .rss: return Theme.edition
    case .refresh: return Theme.unaired
    case .fail: return Theme.danger
    }
}

/// The `.cmd` card frame: a running or stuck run shows its state as the
/// ambient wash over the neutral hairline, never a tinted border.
struct TaskCard: ViewModifier {
    var wash: Color? = nil

    func body(content: Content) -> some View {
        content
            .actWash(wash, radius: 11, base: Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// `TaskName`: name · target detail (N targets).
struct TaskNameLine: View {
    let run: ActivityRun

    var body: some View {
        var text = Text(run.name).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.txt)
        if let detail = TasksLogic.targetDetail(run) {
            text = text + Text(" · \(detail)").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.mut)
        }
        if let count = TasksLogic.targetCountLabel(run) {
            text = text + Text(" (\(count))").font(.system(size: 11.5, weight: .semibold, design: .monospaced)).foregroundColor(Theme.dim)
        }
        return text.lineLimit(2)
    }
}

/// `TaskLine`: the coloured fact segments joined by " · ".
struct TaskFactLine: View {
    let run: ActivityRun

    var body: some View {
        let parts = TasksLogic.factParts(run)
        var text = Text("")
        for (index, part) in parts.enumerated() {
            if index > 0 { text = text + Text(" · ") }
            if let tone = part.tone {
                let color: Color = tone == .grab ? Theme.done : (tone == .up ? Theme.grab : Theme.miss)
                text = text + Text(part.text).font(.system(size: 12.5, weight: .bold, design: .monospaced)).foregroundColor(color)
            } else {
                text = text + Text(part.text)
            }
        }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
            .padding(.top, 3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The 5pt run bar (`.bar`): gradient fill, live sweep while indeterminate.
struct TaskBar: View {
    let fraction: Double
    var live = false
    var done = false

    var body: some View {
        ActProgressBar(fraction: fraction, height: 5,
                       fill: done ? AnyShapeStyle(Theme.done)
                                  : AnyShapeStyle(Theme.i1),
                       shimmer: live)
            .padding(.top, 8)
    }
}
