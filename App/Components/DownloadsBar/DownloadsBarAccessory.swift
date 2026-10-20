import SwiftUI
import FusionhaKit

/// The downloads bar: the shell's tab-bar bottom accessory (iOS-only; the web
/// has no equivalent). It belongs to the tab view, which is the shell's
/// leading pane, so on iPhone Duo it never enters the title column or the fold.
/// Shown while the queue has items, hidden on Activity (the Queue is already
/// there). iOS before 26.1 has no way to hide an accessory, so it goes without.
struct DownloadsBarSlot: ViewModifier {
    let state: DownloadsBarState
    let shown: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: shown) { DownloadsBarAccessory(state: state) }
        } else {
            content
        }
    }
}

/// The accessory's content: expanded above the tab bar, or one line beside
/// the minimised tab bar (`tabViewBottomAccessoryPlacement == .inline`).
struct DownloadsBarAccessory: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: DownloadsBarState
    @State private var confirmPause = false

    private var inline: Bool { placement == .inline }
    private var animation: Animation? { reduceMotion || !model.animationsEnabled ? nil : .smooth(duration: 0.6) }

    var body: some View {
        Group {
            if let done = state.finished {
                bar(done, finished: true)
            } else if let summary = state.summary {
                bar(summary, finished: false)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .confirmationDialog("Pause fusionha's downloads?", isPresented: $confirmPause, titleVisibility: .visible) {
            Button("Pause downloads") { Task { await model.toggleQueuePause() } }
        } message: {
            Text("Only the downloads fusionha tracks pause; anything else in your download clients keeps going. New grabs wait until you resume.")
        }
    }

    private func bar(_ s: DownloadsBar.Summary, finished: Bool) -> some View {
        Button { openQueue(finished ? nil : s.leadId) } label: {
            Group {
                if inline {
                    DownloadsBarInlineRow(summary: s, finished: finished)
                } else {
                    DownloadsBarExpandedRow(summary: s, finished: finished)
                }
            }
            .padding(.horizontal, inline ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if !inline && !finished && s.need == nil {
                    DownloadsBarHairline(fraction: s.leadFraction).padding(.bottom, 1)
                }
            }
            .background {
                if finished {
                    DownloadsBarWash(color: Theme.done)
                } else if s.need != nil {
                    DownloadsBarWash(color: Theme.stuck)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(animation, value: s)
        .accessibilityLabel(finished ? DownloadsBar.spokenFinished(s) : DownloadsBar.spoken(s))
        .accessibilityHint("Opens the queue")
        .contextMenu { menu(s) }
    }

    @ViewBuilder
    private func menu(_ s: DownloadsBar.Summary) -> some View {
        Button("Open title", systemImage: "film") { model.presentedItem = ItemRef(id: s.mediaItemId) }
        // The Activity toolbar's own Pause (admins, 0.4.205).
        if model.me?.isAdmin == true {
            let paused = model.queuePaused
            Button(paused ? "Resume downloads" : "Pause downloads", systemImage: paused ? "play.fill" : "pause.fill") {
                if paused { Task { await model.toggleQueuePause() } } else { confirmPause = true }
            }
        }
    }

    /// Activity › Queue, scrolled to the lead (the widgets' deep link).
    private func openQueue(_ downloadId: Int?) {
        let link = downloadId.map { "fusionha://activity/queue?focus=\($0)" } ?? "fusionha://activity/queue"
        if let url = URL(string: link) { model.handleDeepLink(url) }
    }
}

/// Expanded: thumb (or the needs-you / done symbol), the title with its
/// edition chip, the count · sizes · time line and the overall ring (the
/// lead's own progress is the bar's hairline).
struct DownloadsBarExpandedRow: View {
    let summary: DownloadsBar.Summary
    let finished: Bool

    var body: some View {
        let s = summary
        HStack(spacing: 10) {
            if finished {
                DownloadsBarSymbol(kind: .done)
            } else if s.need != nil {
                DownloadsBarSymbol(kind: .needsYou)
            } else {
                DownloadsBarThumb(url: s.posterUrl)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(s.heading)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    TierPill(tier: s.leadTier)
                        .fixedSize()
                }
                Text(finished ? DownloadsBar.finishedLine : DownloadsBar.detailLine(s))
                    .font(.caption)
                    // Ink, not `mut`: the line sits on clear glass over posters.
                    .foregroundStyle(Theme.txt.opacity(0.78))
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            if !finished && s.downloading > 0 {
                DownloadsBarRing(percent: s.percent)
            }
        }
    }
}

/// Inline (tab bar minimised): "3 downloading", every tier's chip, the ring.
struct DownloadsBarInlineRow: View {
    let summary: DownloadsBar.Summary
    let finished: Bool

    var body: some View {
        let s = summary
        HStack(spacing: 8) {
            if finished {
                DownloadsBarSymbol(kind: .done, compact: true)
            } else if s.need != nil {
                DownloadsBarSymbol(kind: .needsYou, compact: true)
            } else {
                DownloadsBarThumb(url: s.posterUrl, compact: true)
            }
            Text(finished ? "Imported" : DownloadsBar.inlineLine(s))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .contentTransition(.numericText())
            ForEach(finished ? [s.leadTier] : s.tiers, id: \.self) { tier in
                TierPill(tier: tier).fixedSize()
            }
            Spacer(minLength: 0)
            if !finished && s.downloading > 0 {
                DownloadsBarRing(percent: s.percent, size: 28)
            }
        }
    }
}
