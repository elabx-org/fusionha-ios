import SwiftUI
import UIKit
import GameController

// The perf probe's owner-session script (FUSIONHA_PERF_SCRIPT=v2session): on
// the iPhone Duo harness's flat open inner display, three rounds of what the
// owner does on the v2 Library: sit on it, scroll the grid down and back at
// finger speed, open a movie and a series (cold in round 1, warm after),
// scroll the title page, drag the split handle to full width, back to the
// split and to close (`perfSeamDrag`, a 240 ms drag let go at a velocity),
// open one title while another is open, then switch tabs (Activity, Search)
// and open a title from Search results. Every step is a phase (frame pacing,
// long frames, main-thread time, counters, the sampler's stall stacks); the
// opens and closes also print an `open` event (PerfProbe+Open.swift).

#if DEBUG
extension PerfProbe {
    /// Movie and series pairs from the fixtures (their detail pages exist).
    private static let sessionTitles: [(Int, Int)] = [(1, 8), (2, 10), (1, 8)]

    func runSession(warmup: Double) async {
        UserDefaults.standard.set(true, forKey: "v2.splitHandle.used")
        model.pendingAllTitles = true  // v2: the grid is All titles, over Home
        model.tab = .library
        let start = CACurrentMediaTime()
        while !(model.libraryLoaded && model.library.count > 100), CACurrentMediaTime() - start < 60 {
            try? await Task.sleep(for: .milliseconds(250))
        }
        if model.library.isEmpty { await model.loadLibrary() }
        emit(["event": "library", "label": "v2session", "titles": model.library.count,
              "error": model.libraryError ?? ""])
        emit(["event": "input", "hardware_keyboard": GCKeyboard.coalesced != nil, "focus": focusState()])
        await phase("session.settle", warmup)
        for (index, pair) in Self.sessionTitles.enumerated() {
            await sessionRound(index + 1, movie: pair.0, series: pair.1)
        }
        emit(["event": "input", "hardware_keyboard": GCKeyboard.coalesced != nil, "focus": focusState()])
        emit(["event": "done"])
        FileHandle.standardError.write(Data("PERF DONE\n".utf8))
    }

    private func sessionRound(_ r: Int, movie: Int, series: Int) async {
        let p = "r\(r)"
        await toLibraryTop()
        await phase("\(p).library.idle", 3)
        prefersTallest = true
        scrollSpeed = 1800
        await phase("\(p).library.scroll", 3, scroll: true)
        scrollSpeed = -1800
        await phase("\(p).library.scroll", 3, scroll: true)
        await toLibraryTop()

        await measureOpen(movie, label: "\(p).open.movie")
        await phase("\(p).title.idle", 2)
        prefersTallest = false
        scrollSpeed = 1200
        await phase("\(p).title.scroll", 2.5, scroll: true)
        scrollSpeed = -1200
        await phase("\(p).title.scroll", 2.5, scroll: true)

        let rest = sessionRest()
        await seamDrag("\(p).seam.full", dx: -rest + 30, velocity: -900)
        await seamDrag("\(p).seam.split", dx: rest - 30, velocity: 900)
        await measureOpen(series, label: "\(p).swap.series")
        await phase("\(p).swap.idle", 2)
        await seamDrag("\(p).seam.close", dx: (sessionWidth() - rest) * 0.45, velocity: 1600)
        await phase("\(p).closed.idle", 2)

        model.tab = .activity
        await phase("\(p).tab.activity", 3)
        model.tab = .search
        await phase("\(p).tab.search", 2)
        model.searchQuery = "the"
        model.searchText = "the"
        await phase("\(p).search.results", 3)
        await measureOpen(r == 2 ? series : movie, label: "\(p).search.open")
        await phase("\(p).search.title.idle", 2)
        await measureClose(label: "\(p).search.close")
        model.searchQuery = ""
        model.searchText = ""
        model.tab = .library
        await phase("\(p).tab.library", 3)
    }

    /// One drag of the split handle, measured until the seam has settled.
    private func seamDrag(_ label: String, dx: Double, velocity: Double) async {
        await phase(label, 2.5) {
            NotificationCenter.default.post(name: .perfSeamDrag, object: [dx, velocity])
        }
    }

    private func toLibraryTop() async {
        prefersTallest = true
        if let sv = findScrollView() {
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: -sv.adjustedContentInset.top), animated: false)
        }
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// Whether UIKit's focus system is on (a hardware keyboard on iPad) and what it holds.
    private func focusState() -> String {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow }
        guard let window, let system = UIFocusSystem.focusSystem(for: window) else { return "none" }
        return system.focusedItem.map { String(describing: type(of: $0)) } ?? "on, nothing focused"
    }

    /// The harness's open inner display (`DuoHarness`, 951 x 669).
    private func sessionWidth() -> Double { 951 }

    private func sessionRest() -> Double { (sessionWidth() / 3).rounded() }
}
#endif
