import SwiftUI
import FusionhaKit

/// v2's downloads bar (plan S8, mock activity.js `downloads`): the tab bar's
/// bottom accessory while the queue has items. The lead download, its T5
/// ticket with the ring and percent, the time left and how many need you,
/// and an orange Review while something is held. Tap opens the Queue; press
/// and hold opens the menu, which reaches each held download directly. The
/// slot, its visibility and the pill space are v1's (`DownloadsBarSlot`).
struct V2DownloadsAccessory: View {
    let state: DownloadsBarState
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.motionEnabled) private var motion
    @State private var confirmPause = false

    private var inline: Bool { placement == .inline }

    var body: some View {
        Group {
            if let done = state.finished {
                row(done, finished: true)
            } else if let summary = state.summary {
                row(summary, finished: false)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .publishesDownloadsPillFrame(inline: inline)
        .confirmationDialog("Pause fusionha's downloads?", isPresented: $confirmPause, titleVisibility: .visible) {
            Button("Pause downloads") { Task { await model.toggleQueuePause() } }
        } message: {
            Text("Only the downloads fusionha tracks pause; anything else in your download clients keeps going. New grabs wait until you resume.")
        }
    }

    private func row(_ s: DownloadsBar.Summary, finished: Bool) -> some View {
        HStack(spacing: 8) {
            Button { V2DownloadsLinks.openQueue(model, focus: finished ? nil : s.leadId) } label: {
                HStack(spacing: 10) {
                    symbol(s, finished: finished)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(s.heading)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.txt)
                                .lineLimit(1)
                            V2DownloadsTicket(summary: s, finished: finished)
                        }
                        if !inline {
                            Text(finished ? DownloadsBar.finishedLine : V2DownloadsLinks.line(s))
                                .font(.caption)
                                .foregroundStyle(Theme.txt.opacity(0.75))
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(finished ? DownloadsBar.spokenFinished(s) : DownloadsBar.spoken(s))
            .accessibilityHint("Opens the queue")
            if !finished, s.needCount > 0, let held = s.heldIds.first {
                Button { V2DownloadsLinks.openQueue(model, focus: held) } label: {
                    Text("Review")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, inline ? 4 : 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.stuck)
                .controlSize(.small)
                .accessibilityLabel("Review what needs you")
            }
        }
        .padding(.horizontal, inline ? 6 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(motion ? .smooth(duration: 0.6) : nil, value: s)
        .contextMenu { V2DownloadsMenu(summary: s, confirmPause: $confirmPause) }
    }

    /// The lead's thumb, or the done tick once it imported.
    @ViewBuilder
    private func symbol(_ s: DownloadsBar.Summary, finished: Bool) -> some View {
        if finished {
            DownloadsBarSymbol(kind: .done, compact: inline)
        } else {
            DownloadsBarThumb(url: s.posterUrl, compact: inline)
        }
    }
}

/// The lead version's T5 ticket: held while it waits on you, else the ring
/// and the overall percent.
struct V2DownloadsTicket: View {
    let summary: DownloadsBar.Summary
    let finished: Bool

    var body: some View {
        let s = summary
        HStack(spacing: 4) {
            if finished {
                EditionBadge(tier: s.leadTier, state: .onDisk, showsCount: false)
            } else if s.need == .held, s.heldIds.first == s.leadId {
                EditionBadge(tier: s.leadTier, state: .held, showsCount: false)
            } else {
                EditionBadge(tier: s.leadTier, state: .downloading(progress: s.leadFraction), showsCount: false)
                if s.downloading > 0 {
                    Text("\(s.percent)%")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.txt.opacity(0.75))
                        .contentTransition(.numericText())
                }
            }
        }
        .fixedSize()
    }
}
