import SwiftUI
import FusionhaKit

// Shared pieces for the native card-list Settings panels (Root Folders, Download
// Clients, Indexers, Connect, Connections, System, Logs …): the page scaffold,
// the web's resource card / pill / icon-button looks, toasts and delete confirms.
// The add/edit Form sheet is in FetchForms.swift, formatting in FetchFormatting.swift.

// MARK: Page

/// A card-list panel page: the web's panel heading (20/750) + subtitle (13 `--mut`)
/// over a 10pt-gutter column of cards, with toasts and delete confirms.
struct FetchingPage<Content: View>: View {
    let slug: String
    var toaster: FetchToaster
    @Binding var confirm: FetchConfirm?
    var refresh: (() async -> Void)?
    @ViewBuilder var content: Content

    private var info: SettingsPanelInfo? { SettingsNav.panel(slug) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(info?.title ?? slug)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.txt)
                    if let subtitle = info?.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 18)
                .settingsReveal()
                content
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg)
        .refreshable { await refresh?() }
        .navigationTitle(info?.title ?? slug)
        .navigationBarTitleDisplayMode(.inline)
        .fetchToasts(toaster)
        .fetchConfirm($confirm)
    }
}

// MARK: Toasts

/// The web's toast: a glass capsule near the bottom with a success / error /
/// warning tint, gone after a few seconds.
@MainActor
@Observable
final class FetchToaster {
    enum Tone { case success, error, warning, info }
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        var title: String?
        var message: String
        var tone: Tone
    }

    private(set) var current: Toast?

    func show(_ message: String, title: String? = nil, tone: Tone = .success) {
        let toast = Toast(title: title, message: message, tone: tone)
        current = toast
        Task {
            try? await Task.sleep(for: .seconds(tone == .error ? 5 : 3.2))
            if current?.id == toast.id { current = nil }
        }
    }

    func error(_ error: Error, title: String? = nil) {
        show(error.settingsMessage, title: title, tone: .error)
    }

    func dismiss() { current = nil }
}

private struct FetchToastOverlay: ViewModifier {
    let toaster: FetchToaster
    @Environment(\.settingsMotionOff) private var motionOff

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let toast = toaster.current {
                    toastView(toast)
                        .transition(motionOff ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(motionOff ? nil : SettingsMotion.reveal(0.35), value: toaster.current)
        }
    }

    private func toastView(_ toast: FetchToaster.Toast) -> some View {
        let tint: Color = switch toast.tone {
        case .success: Theme.done
        case .error: Theme.danger
        case .warning: Theme.miss
        case .info: Theme.cyan
        }
        let icon: String = switch toast.tone {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 15))
            VStack(alignment: .leading, spacing: 2) {
                if let title = toast.title {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(toast.message).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { toaster.dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
                .foregroundStyle(Theme.mut)
                .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}

extension View {
    func fetchToasts(_ toaster: FetchToaster) -> some View {
        modifier(FetchToastOverlay(toaster: toaster))
    }
}

// MARK: Confirm

/// A pending destructive action awaiting the user's OK (the web's `window.confirm`).
struct FetchConfirm: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var action: String = "Delete"
    var destructive = true
    var perform: () -> Void
}

extension View {
    func fetchConfirm(_ request: Binding<FetchConfirm?>) -> some View {
        alert(request.wrappedValue?.title ?? "",
              isPresented: Binding(get: { request.wrappedValue != nil },
                                   set: { if !$0 { request.wrappedValue = nil } }),
              presenting: request.wrappedValue) { pending in
            Button(pending.action, role: pending.destructive ? .destructive : nil) { pending.perform() }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
    }
}

// MARK: Cards

extension View {
    /// The web's resource `.card`: card fill, 1pt hairline, radius 13, padding 15.
    func fetchCard(padding: CGFloat = 15, radius: CGFloat = 13, border: Color = Theme.line) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border))
    }

    /// Staggered `<RevealItem>` entrance for the n-th card of a list.
    func fetchReveal(_ index: Int) -> some View {
        settingsReveal(delay: Double(min(index, 12)) * 0.06)
    }
}

/// The 40pt rounded icon tile at the start of a resource card (`--i2` glyph).
struct FetchIconTile: View {
    let systemName: String
    var tint: Color = Theme.cyan
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// The resource card's status pill (`Connected` / `Failed` / `Disabled` …).
struct FetchPill: View {
    enum Tone { case ok, err, off, warn, accent }
    let text: String
    var tone: Tone = .off

    var body: some View {
        let (fg, bg): (Color, Color) = switch tone {
        case .ok: (Theme.done, Theme.done.opacity(0.16))
        case .err: (Theme.danger, Theme.danger.opacity(0.16))
        case .off: (Theme.mut, Color.white.opacity(0.08))
        case .warn: (Theme.miss, Theme.miss.opacity(0.16))
        case .accent: (Theme.cyan, Theme.cyan.opacity(0.14))
        }
        Text(text)
            .font(.system(size: 10.5, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
            .lineLimit(1)
            .fixedSize()
    }
}

/// A small bordered chip (`.rfKchip`, capability chips …).
struct FetchChip: View {
    let text: String
    var color: Color = Theme.mut
    var border: Color = Theme.line
    var mono = false
    var size: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: mono ? .monospaced : .default))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(border))
            .lineLimit(1)
            .fixedSize()
    }
}

/// The HD / 4K tier chip (`.rfTchip`): mono 9/800, purple for HD, cyan for 4K.
struct FetchTierChip: View {
    let tier: QualityTier

    var body: some View {
        Text(tier.pill)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(tier.color.opacity(0.45)))
            .fixedSize()
    }
}

/// The web's flat `IconButton`: a 30pt square, `--dim` glyph, no chrome at rest.
struct FetchIconButton: View {
    let systemName: String
    let label: String
    var danger = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint ?? (danger ? Theme.danger.opacity(0.85) : Theme.dim))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The dashed full-width add button (`.rfAddRoot`).
struct FetchDashedAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity)
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A section heading row inside a page (`h2` 15/750 + count + description).
struct FetchSectionHead: View {
    let title: String
    var count: Int?
    var description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
            }
            if let description {
                Text(description).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 12)
    }
}

/// The web's `EmptyState`: a dashed box with a centred muted note.
struct FetchEmpty: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}

/// Loading / error line for a panel body.
struct FetchLoading: View {
    var error: String?
    var text = "Loading…"

    var body: some View {
        HStack(spacing: 10) {
            if let error {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.miss)
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                ProgressView().controlSize(.small)
                Text(text).font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
        }
        .padding(.vertical, 12)
    }
}
