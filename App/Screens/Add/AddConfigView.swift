import SwiftUI
import FusionhaKit

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

    @Environment(\.motionEnabled) var motion
    @State var splitChosen = false
    @State private var editingRow: QualityTier = .uhd
    @State private var compact = false
    @State var phase: AddPhase = .idle
    @State private var today = Date()

    enum AddPhase { case idle, progress, done }

    /// The add moment: the fill runs at least 1.1s, then "✓ Added" holds 650ms.
    static let fillMs = 1100
    static let doneMs = 650

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
                // The hero runs under the sheet's clear system bar; the bar's
                // edge effect only comes in once the title takes over.
                .ignoresSafeArea(.container, edges: .top)
                .scrollEdgeEffectHidden(!compact, for: .top)
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
        }
        .background(Theme.bg)
        // Close and Back are system toolbar items (DC10, D4), so the Duo can
        // move them into its vertical bar; the hero stays clean. Scrolled
        // past the hero, the bar takes the title.
        .navigationTitle(compact ? TitleYear.display(flow.title, flow.year).title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
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
                               onClose: nil)
        if let zoom {
            view.matchedTransitionSource(id: zoom.id, in: zoom.namespace)
        } else {
            view
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close", action: onClose)
        }
        if let onSearchAgain {
            ToolbarItem(placement: .navigation) {
                Button("Back to search", systemImage: "chevron.left", action: onSearchAgain)
            }
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
}

/// A text link with its chevron before or after the title.
private struct LinkLabelStyle: LabelStyle {
    let leading: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            if leading { configuration.icon.font(.system(size: 11, weight: .bold)) }
            configuration.title
            if !leading { configuration.icon.font(.system(size: 11, weight: .bold)) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
