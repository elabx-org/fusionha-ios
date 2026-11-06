import SwiftUI

// MARK: - Scroll thumb (components/library/ScrollScrubber.tsx)

/// The scroll thumb's state, shared by the Library scroll (writer) and the
/// thumb overlay (reader), so scrolling never re-renders the page itself.
@MainActor
@Observable
final class ScrubberState {
    /// Idle time after the last scroll before the thumb fades out.
    static let hideAfter: TimeInterval = 1.4
    /// Hold time on the thumb that grabs it.
    static let holdTime: Duration = .milliseconds(180)
    /// Finger travel on the thumb that grabs it without waiting for the hold.
    static let engageDistance: CGFloat = 8
    /// Minimum gap between real jumps while scrubbing (F-B).
    static let jumpGap: TimeInterval = 0.12
    /// Thumb height, also the bubble's reference.
    static let thumbHeight: CGFloat = 48

    struct Metrics: Equatable {
        var offset: CGFloat
        var maxOffset: CGFloat
        var viewport: CGFloat

        init(_ geo: ScrollGeometry) {
            offset = geo.contentOffset.y + geo.contentInsets.top
            viewport = geo.containerSize.height
            maxOffset = geo.contentSize.height + geo.contentInsets.top + geo.contentInsets.bottom - viewport
        }
    }

    /// Scroll progress (0–1): where the thumb sits on its track.
    var progress: CGFloat = 0
    var visible = false { didSet { if visible != oldValue { onVisibility?(visible) } } }
    /// Told when the thumb shows or hides (the Duo's trailing-edge swipe stands aside).
    @ObservationIgnored var onVisibility: ((Bool) -> Void)?
    /// The letter in the bubble; nil hides it.
    var bubble: String?
    /// Bumped once per new letter while scrubbing: drives the haptic and the bubble's tick.
    var tick = 0
    /// The grid's first row, in global coordinates: the track never starts above it.
    var gridTop: CGFloat = 0
    /// The grid's trailing edge, in global coordinates: the thumb hugs the
    /// page's side margin, whatever the safe area reports (on the open Duo the
    /// system column was subtracted twice and the thumb sat over the posters).
    var gridTrailing: CGFloat?

    /// The letter at the top of the grid (scroll-spy), shown when the thumb is grabbed.
    @ObservationIgnored var activeLetter: String?
    @ObservationIgnored private(set) var scrubbing = false
    @ObservationIgnored private var lastScroll = Date.distantPast
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var lastLetter: String?
    @ObservationIgnored private var lastJump = Date.distantPast
    @ObservationIgnored private var pending: String?

    func setGridTop(_ y: CGFloat) {
        // Above the window's top the track starts at the safe area whatever
        // the grid's y: clamped, scrolling past stops writing it every frame
        // (each write re-ran the thumb's whole body).
        let y = max(y, 0)
        // Frozen while scrubbing: a jump scrolls the page, and moving the track
        // under the finger would shift the finger → letter mapping mid-drag.
        guard !scrubbing, abs(y - gridTop) >= 0.5 else { return }
        gridTop = y
    }

    func setGridTrailing(_ x: CGFloat) {
        guard !scrubbing, abs(x - (gridTrailing ?? -1)) >= 0.5 else { return }
        gridTrailing = x
    }

    /// Any scroll (momentum included) shows the thumb at the page's progress and
    /// restarts the idle timer. Only for a page long enough to be worth scrubbing.
    func scrolled(_ m: Metrics) {
        guard !scrubbing, m.maxOffset >= m.viewport * 0.5 else { return }
        let p = min(1, max(0, m.offset / max(m.maxOffset, 1)))
        // About half a point of thumb travel (the track is shorter than the
        // viewport): a long library moves the thumb a fraction of a point per
        // frame, and every write re-renders it.
        if abs(p - progress) >= 0.5 / max(m.viewport, 1) || p == 0 || p == 1, p != progress { progress = p }
        if !visible { visible = true }
        lastScroll = Date()
        scheduleHide()
    }

    private func scheduleHide() {
        guard hideTask == nil else { return }
        hideTask = Task { [weak self] in
            while true {
                guard let wait = self.map({ $0.lastScroll.timeIntervalSinceNow + Self.hideAfter }) else { return }
                if wait <= 0 { break }
                try? await Task.sleep(for: .seconds(wait))
                if Task.isCancelled { return }
            }
            guard let self else { return }
            hideTask = nil
            if !scrubbing { visible = false }
        }
    }

    private func entry(at y: CGFloat, height: CGFloat, letters: [String]) -> (ratio: CGFloat, letter: String?) {
        let span = max(1, height - Self.thumbHeight)
        let ratio = min(1, max(0, (y - Self.thumbHeight / 2) / span))
        guard !letters.isEmpty else { return (ratio, nil) }
        return (ratio, letters[min(letters.count - 1, Int(ratio * CGFloat(letters.count)))])
    }

    /// Grabbing never moves the grid: the letter under the finger seeds the
    /// "last letter", and the bubble shows the letter the grid is actually on.
    func engage(at y: CGFloat, height: CGFloat, letters: [String]) {
        guard !scrubbing else { return }
        scrubbing = true
        hideTask?.cancel()
        hideTask = nil
        visible = true
        let under = entry(at: y, height: height, letters: letters).letter
        lastLetter = under
        bubble = activeLetter ?? under
    }

    func scrub(to y: CGFloat, height: CGFloat, letters: [String], jump: (String) -> Void) {
        let (ratio, letter) = entry(at: y, height: height, letters: letters)
        progress = ratio
        guard let letter, letter != lastLetter else { return }
        lastLetter = letter
        bubble = letter
        tick &+= 1
        if Date().timeIntervalSince(lastJump) >= Self.jumpGap {
            lastJump = Date()
            pending = nil
            jump(letter)
        } else {
            pending = letter
        }
    }

    #if DEBUG
    /// CI screenshots (`FUSIONHA_SCREENSHOT_SCRUB`): park the thumb on a letter's
    /// row, held as if grabbed so it never fades; `bubble` also shows the letter
    /// bubble, as mid-scrub.
    func screenshotHold(letter: String, bubble showBubble: Bool, letters: [String], jump: (String) -> Void) {
        guard let index = letters.firstIndex(of: letter) else { return }
        jump(letter)
        scrubbing = true
        hideTask?.cancel()
        hideTask = nil
        progress = (CGFloat(index) + 0.5) / CGFloat(letters.count)
        visible = true
        if showBubble {
            bubble = letter
            tick &+= 1
        }
    }
    #endif

    /// Lift: the letter under the finger always lands.
    func end(jump: (String) -> Void) {
        let was = scrubbing
        scrubbing = false
        lastLetter = nil
        bubble = nil
        if let pending { jump(pending) }
        pending = nil
        lastJump = .distantPast
        if was {
            lastScroll = Date()
            scheduleHide()
        }
    }
}

/// The phone Library's jump-to-letter control: a Plex-style scroll thumb that
/// replaces the permanent A–Z rail. Hidden at rest; any scroll slides it in at
/// the right edge like a scrollbar thumb, and it fades 1.4s after the last
/// scroll. Hold it (180ms) or drag it (8pt) to grab it: a letter bubble shows
/// beside the finger, the finger's height picks from the letters that have
/// titles, the grid jumps, and each new letter plays a selection haptic. The
/// track itself is click-through; only the visible thumb takes touches.
struct ScrollScrubber: View {
    let state: ScrubberState
    /// The letters that have titles, in A–Z order ('#' first).
    let letters: [String]
    let jump: (String) -> Void

    static let space = "scroll-scrubber-track"

    var body: some View {
        let _ = PerfCount.hit("ScrollScrubber.body")
        if !letters.isEmpty {
            GeometryReader { geo in
                let _ = PerfCount.hit("ScrollScrubber.reader")
                let origin = geo.frame(in: .global).minY
                let top = max(geo.safeAreaInsets.top + 12, state.gridTop - origin)
                let bottom = geo.size.height - geo.safeAreaInsets.bottom - 12
                let height = max(bottom - top, ScrubberState.thumbHeight * 2)
                // Its own view: a scroll moves the thumb (`progress`) without
                // re-running this reader.
                ScrubberTrack(state: state, letters: letters, height: height, jump: jump)
                    .frame(width: 110, height: height)
                    .coordinateSpace(.named(Self.space))
                    .offset(x: trailingEdge(geo) - 110, y: top)
            }
            .sensoryFeedback(.selection, trigger: state.tick)
            .accessibilityHidden(true)
            #if DEBUG
            .task(id: letters) { await screenshotScrub() }
            #endif
            .overlay(alignment: .topTrailing) { voiceOverIndex }
        }
    }

    /// The track's trailing edge: the grid's edge plus its 16 pt side margin,
    /// which the page already keeps clear of a vertical system bar (iPhone
    /// Duo) or the camera housing. Before the grid is measured, inside the
    /// trailing safe area.
    private func trailingEdge(_ geo: GeometryProxy) -> CGFloat {
        let fallback = geo.size.width - geo.safeAreaInsets.trailing
        guard let grid = state.gridTrailing else { return fallback }
        return min(geo.size.width, grid + 16 - geo.frame(in: .global).minX)
    }

    #if DEBUG
    /// `FUSIONHA_SCREENSHOT_SCRUB=thumb` shows the resting thumb mid-library;
    /// a letter (e.g. `S`) shows the scrubbing state on it, bubble included;
    /// `sweep` scrubs far back and forth, then scrolls normally under the hang
    /// check, `drift` only scrolls (LibraryScrubberDebug.swift), and `jump`
    /// captures the silhouette a far jump lands on (LibraryJumpDebug.swift).
    private func screenshotScrub() async {
        guard let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SCRUB"], !raw.isEmpty,
              letters.count > 1 else { return }
        try? await Task.sleep(for: .seconds(1.5))
        if raw == "sweep" { return await state.screenshotSweep(letters: letters, jump: jump) }
        if raw == "drift" { return await ScrubberState.screenshotDrift() }
        if raw == "hang-selftest" { return await HangWatchdog.selfTest() }
        if raw == "jump" { return await state.screenshotJump(letters: letters, jump: jump) }
        let thumb = raw == "thumb"
        let letter = thumb ? letters[letters.count / 2] : raw.uppercased()
        // Land the jump first: the hold freezes the track's top, and frozen
        // before the grid moved up (a tall home above it) it parked the
        // thumb below the screen.
        if letters.contains(letter) { jump(letter) }
        try? await Task.sleep(for: .milliseconds(600))
        state.screenshotHold(letter: letter, bubble: !thumb, letters: letters, jump: jump)
    }
    #endif

    /// The web's visually-hidden letter list: every letter stays reachable for
    /// VoiceOver as one adjustable element.
    private var voiceOverIndex: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel("Jump to letter")
            .accessibilityValue(state.activeLetter ?? letters.first ?? "")
            .accessibilityAdjustableAction { direction in
                let current = letters.firstIndex(of: state.activeLetter ?? "") ?? 0
                let next = direction == .increment ? min(current + 1, letters.count - 1) : max(current - 1, 0)
                state.activeLetter = letters[next]
                jump(letters[next])
            }
    }
}
