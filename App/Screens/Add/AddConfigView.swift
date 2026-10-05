import SwiftUI
import FusionhaKit

/// A sentence built from `SummaryPart`s: strong parts in the text colour.
struct AddSummaryText: View {
    let parts: [SummaryPart]
    var prefix: String?

    var body: some View {
        parts.reduce(prefix.map { Text("\($0) ").fontWeight(.bold).foregroundColor(Theme.txt) } ?? Text("")) { text, part in
            text + (part.strong ? Text(part.text).fontWeight(.semibold).foregroundColor(Theme.txt) : Text(part.text))
        }
        .foregroundStyle(Theme.mut)
        .fixedSize(horizontal: false, vertical: true)
        .contentTransition(.opacity)
        .animation(.easeOut(duration: 0.2), value: parts.map(\.text).joined())
    }
}

/// The Add title v2 configure step (web `AddConfigPanel`, phone layout): the
/// detail page's hero scrolling with the decisions, the "Search again" and
/// "View details" links, Details · Versions · What to monitor (series) or
/// When to grab it (movies), and a sticky footer with the live sentence,
/// Search now and the Add button.
struct AddConfigView: View {
    let flow: AddFlow
    var onSearchAgain: (() -> Void)?
    var onViewDetails: (() -> Void)?
    let onClose: () -> Void
    let onAdded: (AddedTitle) -> Void
    /// The hero is the zoom source for the "View details" push.
    var zoom: (id: String, namespace: Namespace.ID)?

    @Environment(\.motionEnabled) private var motion
    @State private var splitChosen = false
    @State private var editingRow: QualityTier = .uhd
    @State private var compact = false
    @State private var phase: AddPhase = .idle
    @State private var today = Date()

    enum AddPhase { case idle, progress, done }

    /// The add moment: the fill runs at least 1.1s, then "✓ Added" holds 650ms.
    private static let fillMs = 1100
    private static let doneMs = 650

    private var poster: String? { flow.pick.posterUrl ?? flow.preview?.posterUrl }
    private var backdrop: String? { flow.pick.backdropUrl ?? flow.preview?.backdropUrl }
    private var kindLabel: String { flow.effectiveAnime ? "Anime" : flow.isSeries ? "Series" : "Movie" }

    var body: some View {
        let timeline = flow.timeline(today: today)
        ZStack(alignment: .top) {
            PreviewAmbient(art: poster ?? backdrop)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        links
                        sections(timeline)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 200 } action: { _, new in
                    withAnimation(motion ? .easeOut(duration: 0.2) : nil) { compact = new }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { footer(timeline) }
                #if DEBUG
                .onChange(of: flow.ready && !flow.previewLoading) { _, settled in
                    if settled { screenshotHooks(proxy) }
                }
                #endif
            }
            compactBar
        }
        .background(Theme.bg)
        .onAppear { flow.start() }
        .task(id: flow.effectiveAnime) { await flow.loadLast() }
    }

    // MARK: Hero

    private var heroMeta: [PreviewHero.Meta] {
        var items: [PreviewHero.Meta] = [.text(kindLabel)]
        if let runtime = Self.runtime(flow.preview?.runtime) { items.append(.text(runtime)) }
        if let vote = flow.preview?.voteAverage, vote > 0 { items.append(.rating(vote)) }
        if let cert = flow.preview?.certification, !cert.isEmpty { items.append(.cert(cert)) }
        // Movies are always TMDB-built; a series credits its effective provider.
        let provider = flow.isSeries ? flow.effectiveProvider : "tmdb"
        if provider != "auto" { items.append(.text("Metadata via \(Self.providerShort(provider))")) }
        return items
    }

    @ViewBuilder
    private var hero: some View {
        let shown = TitleYear.display(flow.title, flow.year)
        let view = PreviewHero(art: poster ?? backdrop, status: flow.preview?.status, title: shown.title, year: shown.year,
                               tagline: flow.preview?.tagline, meta: heroMeta, genres: flow.preview?.genres ?? [],
                               onClose: onClose, onBack: onSearchAgain, backLabel: "Back to search")
        if let zoom {
            view.matchedTransitionSource(id: zoom.id, in: zoom.namespace)
        } else {
            view
        }
    }

    @ViewBuilder
    private var links: some View {
        if onSearchAgain != nil || onViewDetails != nil {
            HStack(spacing: 16) {
                if let onSearchAgain {
                    Button(action: onSearchAgain) {
                        Label("Not this one? Search again", systemImage: "chevron.left")
                            .labelStyle(LinkLabelStyle(leading: true))
                    }
                }
                if let onViewDetails {
                    Button(action: onViewDetails) {
                        Label("View details", systemImage: "chevron.right")
                            .labelStyle(LinkLabelStyle(leading: false))
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Theme.i2)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
        }
    }

    private static func runtime(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m) min"
    }

    private static func providerShort(_ provider: String) -> String {
        switch provider {
        case "tmdb": return "TMDB"
        case "tvdb": return "TVDB"
        case "tvmaze": return "TVmaze"
        case "hybrid": return "Hybrid"
        default: return provider
        }
    }

    // MARK: Sections

    private func sections(_ timeline: ReleaseTimelineModel) -> some View {
        let ids = flow.ids
        let idCount = [ids.tmdb != nil, ids.tvdb != nil, !(ids.imdb ?? "").isEmpty].filter { $0 }.count
        let split = flow.onTiers.count == 2
            && (splitChosen || (flow.versions?[.uhd]?.monitor ?? flow.monitor) != flow.monitor)
        let master = flow.isSeries ? flow.monitorSummary(flow.monitor, withCustom: !split) : nil
        let monitorCount = flow.monitor == "future" ? "new only"
            : master.flatMap { $0.exact ? "\($0.count) \($0.count == 1 ? "episode" : "episodes")" : nil }
        let stop = timeline.stops.first { $0.key == flow.minAvail } ?? timeline.stops[0]
        return VStack(alignment: .leading, spacing: 0) {
            section("Details", count: idCount > 0 ? "\(idCount) \(idCount == 1 ? "id" : "ids") linked" : nil, first: true) {
                AddDetailsCard(flow: flow)
            }
            .id("details")
            section("Versions", count: flow.ready ? "\(flow.onTiers.count) on" : nil, action: AnyView(lastLink)) {
                if flow.ready {
                    AddTierCards(flow: flow)
                } else {
                    VStack(spacing: 10) {
                        SkeletonBar(height: 292, radius: 16)
                        SkeletonBar(height: 192, radius: 16)
                    }
                    .accessibilityLabel("Loading your default folders and profiles")
                }
            }
            .id("versions")
            if flow.isSeries {
                section("What to monitor", count: monitorCount) {
                    AddMonitorStrip(flow: flow, splitChosen: $splitChosen, editingRow: $editingRow)
                }
                .id("monitor")
            } else {
                section("When to grab it", count: flow.previewLoading ? nil : stop.label) {
                    if flow.previewLoading {
                        VStack(alignment: .leading, spacing: 10) {
                            SkeletonBar(height: 112, radius: 14)
                            SkeletonBar(height: 14, radius: 5).frame(width: 220)
                        }
                        .accessibilityLabel("Loading release dates")
                    } else {
                        GrabTimeline(timeline: timeline, value: flow.minAvail) { flow.setMinAvail($0) }
                    }
                }
                .id("monitor")
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var lastLink: some View {
        if flow.lastAvailable {
            Button {
                withAnimation(motion ? .snappy(duration: 0.3) : nil) {
                    if flow.lastApplied { flow.undoLast() } else { flow.applyLast() }
                }
            } label: {
                if flow.lastApplied {
                    (Text("✓ Last settings · ") + Text("Undo").underline().foregroundColor(Theme.mut))
                        .foregroundStyle(Theme.done)
                } else {
                    Text("⟲ Use last settings").foregroundStyle(Theme.i2)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityHint(flow.lastApplied ? "Undo: back to what you had"
                               : "Apply your last \(flow.effectiveAnime ? "anime" : flow.isSeries ? "series" : "movie") add"
                               + (flow.last?.title.map { " (\($0))" } ?? "") + ": \(flow.lastSummary)")
            .sensoryFeedback(.selection, trigger: flow.lastApplied)
        }
    }

    private func section<Content: View>(
        _ title: String, count: String?, first: Bool = false, action: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.54)
                    .foregroundStyle(Theme.mut)
                    .accessibilityAddTraits(.isHeader)
                if let count {
                    Text(count)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                if let action { action }
            }
            .frame(minHeight: 24)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, first ? 22 : 11)
        .padding(.bottom, 11)
        .background {
            if first {
                LinearGradient(stops: [.init(color: Theme.bg.opacity(0), location: 0),
                                       .init(color: Theme.bg.opacity(0.62), location: 0.12)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                Theme.bg.opacity(0.62)
            }
        }
    }

    // MARK: Footer

    private func footer(_ timeline: ReleaseTimelineModel) -> some View {
        let split = flow.onTiers.count == 2
            && (splitChosen || (flow.versions?[.uhd]?.monitor ?? flow.monitor) != flow.monitor)
        let stop = timeline.stops.first { $0.key == flow.minAvail } ?? timeline.stops[0]
        let parts = AddSentence.summary(
            isSeries: flow.isSeries,
            versions: flow.onTiers.map { ($0, flow.editions[$0]) },
            searchNow: flow.searchNow,
            monitor: flow.isSeries ? flow.monitorSummary(flow.monitor, withCustom: !split) : nil,
            monitorUhd: flow.isSeries && split ? flow.monitorSummary(flow.versions?[.uhd]?.monitor ?? flow.monitor, withCustom: false) : nil,
            stop: flow.isSeries ? nil : (label: stop.label, dateText: stop.dateText))
        let busy = phase == .progress || (flow.isAdding && phase != .done)
        let done = phase == .done
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                AddSummaryText(parts: parts).font(.system(size: 13.5))
                if let error = flow.error, !error.folder {
                    Text(error.message).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                }
            }
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { flow.searchNow }, set: { flow.searchNow = $0 })) {
                    Text("Search now").font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                .toggleStyle(LeadingSwitchStyle())
                .frame(minHeight: 44)
                .fixedSize()
                Button { Task { await add() } } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().fill(.white.opacity(0.35))
                                .frame(width: geo.size.width * (phase == .done ? 1 : phase == .progress ? 0.9 : 0))
                        }
                        Text(done ? "✓ Added" : busy ? "Adding…" : "Add \(flow.isSeries ? "series" : "movie")")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Color(hex: 0x08131A))
                            .frame(maxWidth: .infinity)
                            .contentTransition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    .background {
                        if done {
                            Theme.done
                        } else {
                            LinearGradient(colors: [Theme.indigo, Theme.cyan], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .saturation(!done && !busy && !flow.canSubmit ? 0.2 : 1)
                    .brightness(!done && !busy && !flow.canSubmit ? -0.3 : 0)
                    .scaleEffect(busy && motion ? 0.97 : 1)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .disabled(!done && (!flow.canSubmit || busy))
                .allowsHitTesting(!done)
                .accessibilityLabel(done ? "Added" : busy ? "Adding" : "Add \(flow.isSeries ? "series" : "movie")")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Theme.panel.opacity(0.5)), in: .rect(cornerRadius: 0))
        // A scrim under the glass that runs to the screen edge, so the page
        // never reads through the bar or shows below it.
        .background { Theme.bg.opacity(0.88).ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .sensoryFeedback(.success, trigger: done)
    }

    /// The add moment: fill → ✓ Added → close. An error resets the button and
    /// shows inline (on the Folder row for a 409 collision).
    private func add() async {
        guard phase == .idle, flow.canSubmit else { return }
        let started = Date()
        withAnimation(motion ? .timingCurve(0.22, 1, 0.36, 1, duration: Double(Self.fillMs) / 1000) : nil) { phase = .progress }
        guard let item = await flow.submit() else {
            phase = .idle
            return
        }
        if motion {
            let left = Self.fillMs - Int(Date().timeIntervalSince(started) * 1000)
            if left > 0 { try? await Task.sleep(for: .milliseconds(left)) }
        }
        withAnimation(motion ? .easeOut(duration: 0.2) : nil) { phase = .done }
        try? await Task.sleep(for: .milliseconds(Self.doneMs))
        onAdded(item)
    }

    #if DEBUG
    /// CI screenshots: `…_ADD_SCROLL=versions|monitor` scrolls to a section,
    /// `…_ADD_4K` turns the 4K version on and runs its check, `…_ADD_SPLIT`
    /// picks "Different for 4K", `…_ADD_GRAB=<stop>` picks a grab stop.
    private func screenshotHooks(_ proxy: ScrollViewProxy) {
        let env = ProcessInfo.processInfo.environment
        if env["FUSIONHA_SCREENSHOT_ADD_4K"] != nil || env["FUSIONHA_SCREENSHOT_ADD_SPLIT"] != nil {
            flow.setTierOn(.uhd, true)
            if env["FUSIONHA_SCREENSHOT_ADD_4K"] != nil { Task { await flow.checkFourK() } }
        }
        if env["FUSIONHA_SCREENSHOT_ADD_SPLIT"] != nil {
            splitChosen = true
            flow.setTierMonitor(.uhd, "future")
        }
        if let stop = env["FUSIONHA_SCREENSHOT_ADD_GRAB"] { flow.setMinAvail(stop) }
        if let target = env["FUSIONHA_SCREENSHOT_ADD_SCROLL"] {
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }
    #endif

    // MARK: Compact bar

    private var compactBar: some View {
        HStack(spacing: 10) {
            if let onSearchAgain {
                Button(action: onSearchAgain) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to search")
            }
            Text(TitleYear.display(flow.title, flow.year).title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
        .background { Theme.bg.opacity(0.88).ignoresSafeArea(edges: .top) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .opacity(compact ? 1 : 0)
        .offset(y: compact ? 0 : -8)
        .allowsHitTesting(compact)
        .accessibilityHidden(!compact)
    }
}

/// A text link with its chevron before or after the title.
private struct LinkLabelStyle: LabelStyle {
    let leading: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            if leading { configuration.icon.font(.system(size: 10, weight: .bold)) }
            configuration.title
            if !leading { configuration.icon.font(.system(size: 10, weight: .bold)) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// The footer's switch with its label after it ("[switch] Search now").
private struct LeadingSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: configuration.$isOn).toggleStyle(.switch).labelsHidden().tint(Theme.indigo)
            configuration.label
        }
        .contentShape(Rectangle())
    }
}
