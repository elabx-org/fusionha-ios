import SwiftUI
import FusionhaKit

// MARK: - Pill (components/shell/SetupProgressCard.tsx, phone layout)

/// The phone's Live-Activity-style "setting up" pill under the top bar. Collapsed
/// it's a capsule (ring · title · n/N); a tap opens it into the full panel —
/// the steps with their sources, then the first search's result line, or one
/// row per title when several are setting up. It rides the top bar's
/// hide-on-scroll, a swipe up dismisses it, and a finished setup tidies itself
/// away after 5s unless the panel is open.
struct SetupProgressPill: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    /// The top bar's height: the pill floats 8pt below it, or 8pt below the
    /// safe area while the top bar is hidden.
    let barHeight: CGFloat

    private var progress: SetupProgress { model.setupProgress }

    var body: some View {
        let visible = progress.visible
        let primary = visible.first { $0.isActive } ?? visible.first
        ZStack(alignment: .top) {
            if let primary {
                card(primary, visible: visible)
                    .padding(.horizontal, 12)
                    .transition(motion ? .opacity.combined(with: .offset(y: -20)).combined(with: .scale(scale: 0.9, anchor: .top))
                                : .opacity)
            }
        }
        .padding(.top, (model.chromeHidden ? 0 : barHeight) + 8)
        .animation(motion ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.3) : nil, value: model.chromeHidden)
        .animation(motion ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.28) : nil, value: primary == nil)
    }

    private func card(_ primary: TitleSetup, visible: [TitleSetup]) -> some View {
        let open = progress.expanded
        let resultLine = visible.count == 1 ? primary.resultLine(nextRssAt: progress.list.nextRssAt) : nil
        let title = TitleSetup.cardTitle(visible)
        let headTitle = !open && primary.finishedAt != nil ? (resultLine?.text ?? title) : title
        let shape = RoundedRectangle(cornerRadius: open ? 18 : 999, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            head(primary, title: headTitle, fullTitle: title, open: open)
            if open {
                Group {
                    if visible.count == 1 {
                        steps(primary, resultLine: resultLine)
                    } else {
                        multi(visible)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.06)))
            }
        }
        .padding(open ? EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
                      : EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 12))
        .frame(maxWidth: open ? .infinity : nil, alignment: .leading)
        .glassEffect(.regular.tint(Theme.panel2.opacity(0.55)), in: shape)
        .overlay(shape.strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.55), radius: 25, y: 18)
        .contentShape(shape)
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height < -30 {
                withAnimation(motion ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.28) : nil) { progress.dismissAll() }
            }
        })
        .animation(motion ? .interpolatingSpring(mass: 0.9, stiffness: 460, damping: 38) : nil, value: open)
    }

    private func head(_ primary: TitleSetup, title: String, fullTitle: String, open: Bool) -> some View {
        let ring: CGFloat = open ? 40 : 26
        return HStack(spacing: open ? 10 : 9) {
            Group {
                if primary.finishedAt != nil {
                    DoneBadge()
                } else {
                    SetupRing(fraction: primary.progressFraction, track: Theme.txt.opacity(0.14),
                              hole: Theme.panel2, inset: 3)
                }
            }
            .frame(width: ring, height: ring)
            .accessibilityElement()
            .accessibilityLabel("\(fullTitle), \(Int((primary.progressFraction * 100).rounded()))% complete")

            Button {
                progress.expanded.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: open ? 13.5 : 13, weight: .bold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .frame(maxWidth: open ? .infinity : 240, alignment: .leading)
                        .fixedSize(horizontal: !open, vertical: false)
                    if open {
                        Text(primary.nowLabel)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(fullTitle), \(open ? "collapse" : "expand") details")

            let counts = (primary.doneCount, primary.steps.count)
            Text("\(counts.0)/\(counts.1)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.3)
                .monospacedDigit()
                .foregroundStyle(Theme.mut)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
            if open {
                Button {
                    withAnimation(motion ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.28) : nil) { progress.dismissAll() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
    }

    private func steps(_ setup: TitleSetup, resultLine: SetupResultLine?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(setup.steps, id: \.key) { step in
                HStack(alignment: .top, spacing: 10) {
                    StepIcon(status: step.status)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(step.label)
                            .font(.system(size: 13))
                            .foregroundStyle([.done, .running, .failed].contains(step.status) ? Theme.txt : Theme.mut)
                        if let detail = step.detail {
                            Text(detail).font(.system(size: 11)).foregroundStyle(Theme.mut)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let source = step.source {
                        Text(source)
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(0.3)
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
                            .padding(.top, 1)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 2)
            }
            if let resultLine {
                Text(resultLine.text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .statusWash(resultLine.tone == .ok ? Theme.done : Theme.miss,
                                base: Theme.panel2.opacity(0.92), radius: 8)
                    .padding(.top, 8)
            }
        }
    }

    private func multi(_ setups: [TitleSetup]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(setups, id: \.self) { setup in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            model.open(setup.itemId)
                        } label: {
                            Text(setup.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.txt)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        Text(setup.nowLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(setup.finishedAt != nil ? "✓" : "\(setup.doneCount)/\(setup.steps.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                }
            }
        }
    }
}
