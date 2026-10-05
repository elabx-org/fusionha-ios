import SwiftUI
import FusionhaKit

// MARK: - Store (app/SetupProgressProvider.tsx + lib/api/setup-progress.ts)

/// The caller's setups (`GET /api/v1/library/setups`), polled every 2s while
/// anything is setting up and every 20s otherwise, plus the pill's own UI state
/// so every tab shows the same pill.
@MainActor
@Observable
final class SetupProgress {
    /// How long a finished setup lingers before the pill tidies it away.
    static let autoDismiss: Duration = .seconds(5)

    private(set) var list = TitleSetupList()
    /// Setup instances the user dismissed, or that finished and timed out.
    var dismissed: Set<String> = []
    var expanded = false {
        didSet { expanded ? cancelDismissals() : scheduleDismissals() }
    }

    @ObservationIgnored private(set) var lastRefresh = Date.distantPast
    @ObservationIgnored private var signatures: [Int: String] = [:]
    @ObservationIgnored private var primed = false
    @ObservationIgnored private var timers: [String: Task<Void, Never>] = [:]

    /// A setup INSTANCE: adding another version to a finished title starts a new one.
    static func key(_ setup: TitleSetup) -> String { "\(setup.itemId):\(setup.startedAt ?? "")" }

    var visible: [TitleSetup] { list.setups.filter { !dismissed.contains(Self.key($0)) } }

    /// The poster's shimmer + ring read this: only while the setup is still running.
    func activeSetup(for itemId: Int) -> TitleSetup? {
        list.setups.first { $0.itemId == itemId && $0.isActive }
    }

    /// Fetches the list. Returns true when a step finished since the last poll,
    /// so the caller reloads the library (the title's tree or files changed).
    func refresh(client: APIClient) async -> Bool {
        lastRefresh = Date()
        guard let next = try? await client.setups() else { return false }
        var changed = false
        var seen = Set<Int>()
        for setup in next.setups {
            seen.insert(setup.itemId)
            let signature = setup.steps.filter { $0.status.finished }.map(\.key).joined(separator: "|")
            if primed && signatures[setup.itemId] != signature { changed = true }
            signatures[setup.itemId] = signature
        }
        signatures = signatures.filter { seen.contains($0.key) }
        primed = true
        if next != list { list = next }
        let current = Set(next.setups.map(Self.key))
        if !dismissed.isSubset(of: current) { dismissed = dismissed.intersection(current) }
        if visible.isEmpty, expanded { expanded = false }
        #if DEBUG
        applyScreenshotMode()
        #endif
        scheduleDismissals()
        return changed
    }

    #if DEBUG
    /// CI screenshots (`FUSIONHA_SCREENSHOT_SETUP`): `steps` opens the running
    /// setup's panel, `result` the finished one's, `multi` both as rows.
    private func applyScreenshotMode() {
        guard let mode = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SETUP"], !mode.isEmpty else { return }
        let hide = Set(list.setups.filter { setup in
            if mode == "steps" { return !setup.isActive }
            if mode == "result" { return setup.isActive }
            return false
        }.map(Self.key))
        if dismissed != hide { dismissed = hide }
        if !expanded { expanded = true }
    }
    #endif

    func dismissAll() {
        dismissed = Set(list.setups.map(Self.key))
        expanded = false
    }

    private func scheduleDismissals() {
        guard !expanded else { return }
        for setup in list.setups where setup.finishedAt != nil {
            let key = Self.key(setup)
            guard !dismissed.contains(key), timers[key] == nil else { continue }
            timers[key] = Task { [weak self] in
                try? await Task.sleep(for: Self.autoDismiss)
                guard !Task.isCancelled, let self else { return }
                timers[key] = nil
                dismissed.insert(key)
            }
        }
    }

    private func cancelDismissals() {
        timers.values.forEach { $0.cancel() }
        timers = [:]
    }
}

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
            .accessibilityLabel("\(fullTitle) — \(Int((primary.progressFraction * 100).rounded()))% complete")

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
            .accessibilityLabel("\(fullTitle) — \(open ? "collapse" : "expand") details")

            let counts = (primary.doneCount, primary.steps.count)
            Text("\(counts.0)/\(counts.1)")
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
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
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
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

/// A conic progress ring: `--grab` sweeps over a track, with a solid hole.
struct SetupRing: View {
    @Environment(\.motionEnabled) private var motion
    let fraction: Double
    var track: Color = .black.opacity(0.55)
    var hole: Color = Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.85)
    var inset: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().fill(track)
            RingSector(fraction: max(0, min(1, fraction))).fill(Theme.grab)
            Circle().fill(hole).padding(inset)
        }
        .animation(motion ? .easeOut(duration: 0.45) : nil, value: fraction)
    }
}

/// The swept part of a conic ring: a pie slice from 12 o'clock, clockwise.
private struct RingSector: Shape {
    var fraction: Double
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// StatusBadge `check`: an emerald tick on a frosted dark plate.
private struct DoneBadge: View {
    var body: some View {
        GeometryReader { geo in
            Image(systemName: "checkmark")
                .font(.system(size: geo.size.width * 0.36, weight: .bold))
                .foregroundStyle(Theme.done)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.5), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.16)))
        }
    }
}

private struct StepIcon: View {
    @Environment(\.motionEnabled) private var motion
    let status: SetupStepStatus
    @State private var spin = false

    var body: some View {
        switch status {
        case .done, .skipped, .failed:
            Image(systemName: status == .failed ? "xmark" : "checkmark")
                .font(.system(size: status == .failed ? 7.5 : 9, weight: .bold))
                .foregroundStyle(status == .failed ? Theme.danger : Theme.done)
                .frame(width: 18, height: 18)
                .background(Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.5), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.16)))
        case .running:
            Circle()
                .trim(from: 0, to: motion ? 0.75 : 1)
                .stroke(Theme.grab, style: StrokeStyle(lineWidth: 1.5, dash: motion ? [] : [3, 2]))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .onAppear {
                    guard motion else { return }
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true }
                }
                .padding(.top, 1)
        default:
            Circle()
                .strokeBorder(Theme.line, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 1)
        }
    }
}

// MARK: - Poster indicators (PosterCard `.setupRail` + `.setupRing`)

/// A title still setting up: a 3pt `--grab` shimmer rail along the poster's
/// bottom edge and a small progress ring in its bottom-right corner. Under
/// Reduce Motion the rail is a static tinted bar.
struct SetupIndicators: View {
    @Environment(\.motionEnabled) private var motion
    let fraction: Double

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                Spacer(minLength: 0)
                if motion {
                    TimelineView(.animation) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        // `background-size: 200%` sliding to `-200%`: two gradient tiles scroll left.
                        GeometryReader { geo in
                            let w = geo.size.width
                            HStack(spacing: 0) {
                                ForEach(0..<2, id: \.self) { _ in
                                    LinearGradient(colors: [.clear, Theme.grab, .clear],
                                                   startPoint: .leading, endPoint: .trailing)
                                        .frame(width: w * 2)
                                }
                            }
                            .offset(x: -CGFloat(phase) * 2 * w)
                        }
                    }
                    .frame(height: 3)
                } else {
                    Theme.grab.opacity(0.6).frame(height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            SetupRing(fraction: fraction)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Theme.grab.opacity(0.45), lineWidth: 1).padding(-1))
                .padding(8)
                .accessibilityLabel("Setting up")
        }
        .allowsHitTesting(false)
    }
}

/// The step strip under the title-page hero while the title is still setting up
/// (SetupStepStrip): the current step's label + n/N, then one segment per step,
/// filled as each finishes, the running one shimmering.
struct SetupStepStrip: View {
    @Environment(\.motionEnabled) private var motion
    let setup: TitleSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(setup.nowLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text("\(setup.doneCount)/\(setup.steps.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mut)
            }
            HStack(spacing: 4) {
                ForEach(Array(setup.steps.enumerated()), id: \.offset) { _, step in
                    segment(step)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .fill(Theme.panel2)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.grab.opacity(0.1)))
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func segment(_ step: SetupStep) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2)
        if step.status.finished {
            shape.fill(Theme.grab).frame(height: 4).frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.4), value: step.status.finished)
        } else if step.status == .running {
            if motion {
                shape.fill(Theme.line).frame(height: 4).frame(maxWidth: .infinity)
                    .overlay(shape.fill(Theme.grab.opacity(0.7)).shimmer().clipShape(shape))
            } else {
                shape.fill(Theme.grab).frame(height: 4).frame(maxWidth: .infinity)
            }
        } else {
            shape.fill(Theme.line).frame(height: 4).frame(maxWidth: .infinity)
        }
    }
}
