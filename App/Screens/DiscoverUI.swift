import SwiftUI
import UIKit
import WebKit
import FusionhaKit

// The web primitives Discover, Preview, Requests, Issues and You are built
// from (SegmentedControl, Tabs, Button, PosterStatusBadge, StatusWash, EmptyState,
// Toast), sized 1:1 from their CSS.

enum DiscoverPalette {
    /// The hard-coded search/segment well in Discover's CSS.
    static let well = Color(hex: 0x111319)
    /// `color-mix(--i2 45%, --txt)`: the active segment text.
    static let activeText = Color(hex: 0x90E0EF)
    static let activeRing = Color(red: 111 / 255, green: 113 / 255, blue: 242 / 255).opacity(0.54)
    static let tmdb = Color(hex: 0x01B4E4)
    static let tvdb = Color(hex: 0x4FB862)
    static let hybrid = Color(hex: 0xA07CF0)
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

/// `DiscoverArt`: the art fades in from `blur(6px)` + transparent to sharp over 0.55s.
struct DiscoverArt: View {
    let url: URL?
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    @State private var image: UIImage?
    @State private var shown = false

    var body: some View {
        // Color.clear keeps the layout size to the proposal: a filling image
        // would otherwise report its larger size and push its container out.
        Color.clear
            .overlay {
                LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .blur(radius: shown ? 0 : 6)
                        .opacity(shown ? 1 : 0)
                }
            }
        .clipped()
        .task(id: url) {
            guard let url else { image = nil; return }
            if let cached = ImagePipeline.shared.cached(url) {
                image = cached
                shown = true
                return
            }
            shown = false
            image = await ImagePipeline.shared.image(for: url)
            guard !Task.isCancelled else { return }
            if DiscoverMotion.reduced(osReduceMotion) {
                shown = true
            } else {
                withAnimation(.easeOut(duration: 0.55)) { shown = true }
            }
        }
    }
}

/// `Skeleton`: a soft tint with a 1.4s shimmer sweep (static when reduced).
struct DiscoverShimmer: View {
    var radius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(0.06))
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
                        .font(.system(size: size == .md ? 13.5 : 12, weight: .semibold))
                        .foregroundStyle(selected ? DiscoverPalette.activeText : Theme.mut)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, size == .md ? 16 : 11)
                        .padding(.vertical, size == .md ? 9 : 7)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: size == .md ? 10 : 8, style: .continuous)
                                    .fill(Theme.indigo.opacity(0.14))
                                    .overlay(RoundedRectangle(cornerRadius: size == .md ? 10 : 8, style: .continuous)
                                        .strokeBorder(DiscoverPalette.activeRing))
                                    .matchedGeometryEffect(id: "seg", in: indicator)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            if fullTrack { Spacer(minLength: 0) }
        }
        .padding(size == .md ? 4 : 3)
        .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: size == .md ? 13 : 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size == .md ? 13 : 11, style: .continuous).strokeBorder(Theme.line))
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? Theme.txt : Theme.mut)
                        if let badge = options[index].2, badge > 0 {
                            Text("\(badge)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(Color(hex: 0x04121A))
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Theme.grab, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 30)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Theme.panel)
                                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: Button

enum DiscoverButtonKind { case primary, subtle, danger, ghost }

struct DiscoverButtonStyle: ButtonStyle {
    var kind: DiscoverButtonKind = .subtle
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: kind == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: !fullWidth, vertical: false)
            .padding(.horizontal, 11)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 30)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.bg
        case .danger: return Theme.danger
        case .subtle, .ghost: return Theme.txt
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .primary: return AnyShapeStyle(Theme.fusion)
        case .subtle: return AnyShapeStyle(Theme.panel)
        case .danger, .ghost: return AnyShapeStyle(Color.clear)
        }
    }

    private var border: Color {
        switch kind {
        case .primary: return .clear
        case .danger: return Theme.danger.opacity(0.4)
        case .ghost: return .clear
        case .subtle: return Theme.line
        }
    }
}

extension ButtonStyle where Self == DiscoverButtonStyle {
    static func discover(_ kind: DiscoverButtonKind, fullWidth: Bool = false) -> DiscoverButtonStyle {
        DiscoverButtonStyle(kind: kind, fullWidth: fullWidth)
    }
}

/// A 30pt square icon button (trash on request/issue rows).
struct DiscoverIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Theme.mut
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: PosterStatusBadge

enum PosterBadgeKind { case inLibrary, trending, caution }

struct PosterStatusBadge: View {
    let kind: PosterBadgeKind

    var body: some View {
        Group {
            switch kind {
            case .inLibrary:
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.done)
            case .trending:
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(Theme.onair)
            case .caution:
                Image(systemName: "exclamationmark.triangle").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.miss)
            }
        }
        .frame(width: 27, height: 27)
        .background(Color(red: 10 / 255, green: 12 / 255, blue: 18 / 255).opacity(0.5), in: Circle())
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.16)))
        .shadow(color: .black.opacity(0.75), radius: 7, y: 4)
        .accessibilityLabel(kind == .inLibrary ? "In library" : kind == .trending ? "Trending" : "Tracked, no file yet")
    }
}

// MARK: Kind glyphs

/// The torii gate the web uses for anime.
struct DiscoverToriiShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Top beam (kasagi), slightly wider, then the lower tie beam (nuki).
        p.move(to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.2),
                       control: CGPoint(x: rect.midX, y: rect.minY + h * 0.3))
        p.move(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.42))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.16, y: rect.minY + h * 0.42))
        // Posts.
        p.move(to: CGPoint(x: rect.minX + w * 0.28, y: rect.minY + h * 0.24))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.25, y: rect.maxY - h * 0.06))
        p.move(to: CGPoint(x: rect.maxX - w * 0.28, y: rect.minY + h * 0.24))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.25, y: rect.maxY - h * 0.06))
        return p
    }
}

/// Film / TV / torii, the web's per-kind card glyph.
struct DiscoverKindGlyph: View {
    let kind: MediaKind
    let isAnime: Bool
    var size: CGFloat = 13
    var color: Color = Theme.mut

    var body: some View {
        if isAnime {
            DiscoverToriiShape()
                .stroke(color, style: StrokeStyle(lineWidth: max(1.2, size / 10), lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .accessibilityLabel("Anime")
        } else {
            Image(systemName: kind == .movie ? "film" : "tv")
                .font(.system(size: size * 0.85, weight: .regular))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .accessibilityLabel(kind == .movie ? "Movie" : "Series")
        }
    }
}

// MARK: Provider marks

enum MetadataProviderChoice: String, CaseIterable {
    case auto, tmdb, tvdb, hybrid
}

/// The TMDB / TVDB / Hybrid brand marks.
struct DiscoverProviderMark: View {
    let provider: String
    var height: CGFloat = 11

    var body: some View {
        switch provider {
        case "tvdb":
            Image("tvdb-logo").resizable().scaledToFit().frame(height: height)
                .accessibilityLabel("TVDB")
        case "hybrid":
            HStack(spacing: 5) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DiscoverPalette.hybrid)
                Text("Hybrid").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.txt)
            }
        default:
            Image("tmdb-logo").resizable().scaledToFit().frame(height: height)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color(hex: 0x0D253F), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.07)))
                .accessibilityLabel("TMDB")
        }
    }
}

// MARK: Status wash + empty state

extension View {
    /// The ambient status wash: the status colour bleeds from the left over `base`.
    func statusWash(_ color: Color, base: Color = Theme.panel, radius: CGFloat = 14) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(stops: [.init(color: color.opacity(0.13), location: 0),
                                             .init(color: .clear, location: 0.42)],
                                     startPoint: .leading, endPoint: .trailing))
                .background(base, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
    }
}

/// `ui/EmptyState`: dashed hairline box, 13.5pt muted copy.
struct DiscoverEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13.5))
            .lineSpacing(13.5 * 0.6 - 4)
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

/// A 13pt rail/list state line ("Loading…", "Could not load this rail.").
struct RailStateLine: View {
    let text: String
    var error = false

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(error ? Theme.danger : Theme.mut)
            .padding(.vertical, 20)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Uppercase section label used in dialogs ("EDITIONS", "ADD OPTIONS").
struct DialogSectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.66)
                .foregroundStyle(Theme.mut)
            if let trailing {
                Text(trailing).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
            }
        }
    }
}

// MARK: Request status

enum RequestStatusStyle {
    static func color(_ status: String) -> Color {
        switch status {
        case "approved": return Theme.grab
        case "rejected": return Theme.danger
        case "deferred": return Theme.stuck
        case "fulfilled": return Theme.done
        default: return Theme.dim
        }
    }
}

struct RequestStatusPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.22)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .background(Theme.panel2, in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.32)))
    }
}

enum DiscoverRelativeTime {
    /// The web's `formatLastRun`: "just now", "N min ago", "N hr ago", "N day(s) ago".
    static func string(_ iso: String?) -> String {
        guard let date = Format.timestamp(iso) else { return "" }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 45 { return "just now" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(1, minutes)) min ago" }
        let hours = Int((seconds / 3600).rounded())
        if hours < 24 { return "\(hours) hr ago" }
        let days = Int((seconds / 86400).rounded())
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
}

// MARK: DiscoverToasts

enum DiscoverToastVariant { case success, info, error }

struct DiscoverToastMessage: Identifiable, Equatable {
    let id = UUID()
    let variant: DiscoverToastVariant
    let title: String?
    let message: String
}

/// The shared toast queue every Discover-side mutation reports through.
@MainActor
@Observable
final class DiscoverToasts {
    static let shared = DiscoverToasts()
    private(set) var current: DiscoverToastMessage?
    private var hide: Task<Void, Never>?

    func show(_ variant: DiscoverToastVariant, _ message: String, title: String? = nil) {
        let toast = DiscoverToastMessage(variant: variant, title: title, message: message)
        current = toast
        hide?.cancel()
        hide = Task {
            try? await Task.sleep(for: .seconds(variant == .error ? 6 : 4))
            guard !Task.isCancelled else { return }
            if self.current == toast { self.current = nil }
        }
    }

    func error(_ title: String, _ error: Error) {
        show(.error, error.localizedDescription, title: title)
    }

    func dismiss() { current = nil }
}

struct DiscoverToastOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var bottomInset: CGFloat = 72

    func body(content: Content) -> some View {
        let toasts = DiscoverToasts.shared
        content.overlay(alignment: .bottom) {
            if let toast = toasts.current {
                DiscoverToastView(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { toasts.dismiss() }
                    .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: toasts.current)
    }
}

extension View {
    func discoverToastOverlay(bottomInset: CGFloat = 72) -> some View {
        modifier(DiscoverToastOverlay(bottomInset: bottomInset))
    }
}

private struct DiscoverToastView: View {
    let toast: DiscoverToastMessage

    private var color: Color {
        switch toast.variant {
        case .success: return Theme.done
        case .info: return Theme.grab
        case .error: return Theme.danger
        }
    }

    private var icon: String {
        switch toast.variant {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(toast.title == nil ? Theme.txt : Theme.mut)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 15).padding(.trailing, 13).padding(.top, 13).padding(.bottom, 15)
        .frame(maxWidth: 420)
        .statusWash(color, base: Theme.panel.opacity(0.92), radius: Theme.radius)
        .shadow(color: .black.opacity(0.55), radius: 22, y: 18)
        .accessibilityElement(children: .combine)
    }
}

// MARK: YouTube player

/// A YouTube embed (trailer sheet and the Preview's inline trailer).
struct YouTubePlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ view: WKWebView, coordinator: ()) {
        // Stop playback when the sheet closes.
        view.loadHTMLString("", baseURL: nil)
    }
}

/// `TrailerModal`: a bottom sheet with the 16:9 embed.
struct TrailerSheet: View {
    let title: String
    let key: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("Trailer").font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.mut)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.bottom, 14)
            if let url = URL(string: "https://www.youtube.com/embed/\(key)?autoplay=1&rel=0&playsinline=1") {
                YouTubePlayer(url: url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .background(Theme.panel)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
