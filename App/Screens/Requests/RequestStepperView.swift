import SwiftUI
import FusionhaKit

extension RequestLifecycle.Tone {
    var color: Color {
        switch self {
        case .done: return Theme.done
        case .unaired: return Theme.unaired
        case .dim: return Theme.dim
        case .mut: return Theme.mut
        case .accent: return Theme.i1
        case .grab: return Theme.grab
        case .attention: return Theme.stuck
        case .danger: return Theme.danger
        case .waiting: return Theme.miss
        case .none: return .clear
        }
    }
}

/// The five-stop stepper for one version (web `LifecycleStepper`): ringed
/// dots coloured per stop, a rail filled to the current stop (green once
/// available, amber when a version needs a manual import), the step names
/// under it, and "Auto-approved" on an automatic approval.
struct RequestStepperView: View {
    let entry: RequestLifecycleEntry
    let auto: Bool

    var body: some View {
        let stop = RequestLifecycle.stopIndex(entry.step)
        let done = entry.step == .available
        let fill = done ? 1 : Double(stop) / Double(RequestLifecycle.steps.count - 1)
        let fillEnd: Color = done ? Theme.done : (entry.needsManualImport ? Theme.stuck : Theme.grab)
        VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    let inset: CGFloat = 9
                    let width = geo.size.width - inset * 2
                    Capsule().fill(Theme.line).frame(width: width, height: 2).offset(x: inset, y: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.i1, fillEnd], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, width * fill), height: 2)
                        .offset(x: inset, y: 8)
                }
                .frame(height: 18)
                HStack(spacing: 0) {
                    ForEach(0..<RequestLifecycle.steps.count, id: \.self) { i in
                        dot(i, stop: stop, done: done)
                        if i < RequestLifecycle.steps.count - 1 { Spacer(minLength: 0) }
                    }
                }
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<RequestLifecycle.steps.count, id: \.self) { i in
                    Text(RequestLifecycle.stopLabel(i, entry: entry, auto: auto))
                        .font(.system(size: 10.5, weight: i == stop ? .bold : .medium))
                        .foregroundStyle(i <= stop || done ? Theme.txt : Theme.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == RequestLifecycle.steps.count - 1 ? .trailing : .center))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(stop + 1) of \(RequestLifecycle.steps.count): \(RequestLifecycle.stopLabel(stop, entry: entry, auto: auto))\(entry.progressPct.map { " \($0)%" } ?? "")")
    }

    private func dot(_ i: Int, stop: Int, done: Bool) -> some View {
        let color = RequestLifecycle.stopTone(i, entry: entry).color
        let state = done || i < stop ? 0 : (i == stop ? 1 : 2)
        return ZStack {
            Circle().fill(Theme.bg)
            switch state {
            case 0:
                Circle().fill(color)
                Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Theme.bg)
            case 1:
                Circle().strokeBorder(color, lineWidth: 2)
                Circle().fill(color).frame(width: 7, height: 7)
            default:
                Circle().strokeBorder(Theme.line, lineWidth: 1.5)
            }
        }
        .frame(width: 18, height: 18)
    }
}

/// The lead version's status line under the stepper (web `RequestStatusLine`).
struct RequestStatusLineView: View {
    let line: RequestLifecycle.StatusLine

    var body: some View {
        switch line {
        case .attention(let text):
            Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.stuck)
        case .progress(let pct):
            HStack(spacing: 8) {
                ActProgressBar(fraction: Double(pct ?? 0) / 100, height: 5, shimmer: true)
                Text(pct.map { "\($0)%" } ?? "Downloading")
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.txt)
                    .fixedSize()
            }
        case .plain(let text, let icon):
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12)) }
                Text(text)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
        case .unreleased(let days):
            HStack(spacing: 10) {
                ZStack {
                    Circle().strokeBorder(Theme.unaired.opacity(0.5), lineWidth: 2)
                    Text(days.map(String.init) ?? "–").font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.unaired)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(days.map { "Waiting for release · \($0) \($0 == 1 ? "day" : "days")" } ?? "Waiting for release")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text("It grabs automatically once it's out").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }
        case .done(let text):
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.done)
        }
    }
}
