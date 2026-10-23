import SwiftUI
import FusionhaKit

/// The web's Library art badges (PosterCard.tsx, owner ruling R1): the 4K flag
/// top right, the Monitor bookmark top left (the select checkbox takes that
/// corner in select mode), and bottom left the attention glyph and the live
/// download state. Each sits on a small dark plate, so it reads on any art.
struct PosterArtBadges: View {
    let badges: PosterBadges
    var showsMonitor = true
    /// The content-first card shows the 4K flag only: its version chips
    /// carry attention and the live download (owner's layout A).
    var showsStatus = true

    var body: some View {
        ZStack {
            if badges.has4k {
                Text("4K")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.onScrim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.scrim.opacity(0.58), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.plateLine))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel("4K")
            }
            if showsMonitor {
                plate {
                    Image(systemName: badges.monitored ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(badges.monitored ? Theme.i2 : Theme.onScrim.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityLabel(badges.monitored ? "Monitored" : "Unmonitored")
            }
            if showsStatus {
                statusMarks
            }
        }
        .padding(8)
    }

    private var statusMarks: some View {
        HStack(spacing: 6) {
            if let attention = badges.attention { AttentionMark(attention: attention) }
            if let live = badges.live { liveMark(live) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func plate<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(width: 22, height: 22)
            .background(Theme.scrim.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func liveMark(_ live: PosterBadges.Live) -> some View {
        plate {
            switch live {
            case .downloading:
                LiveSpinner(color: Theme.grab)
            case .upgrading:
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.edition)
            }
        }
        .accessibilityLabel(live == .downloading ? "Downloading" : "Upgrading")
    }
}

/// The bottom-left ⚠ (files not found) or broken link (dead links only); it
/// breathes softly unless Reduce Motion is on.
private struct AttentionMark: View {
    let attention: PosterBadges.Attention
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        let dead = attention == .deadLink
        let glyph = Image(systemName: dead ? "link" : "exclamationmark.triangle.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(dead ? Theme.stuck : Theme.miss)
            .shadow(color: Theme.scrim.opacity(0.85), radius: 2, y: 1)
            .frame(height: 22)
            .accessibilityLabel(dead ? "Dead link — the symlink target vanished" : "Files not found on the last scan")
        if motion {
            RepeatForever(animation: .easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { on in
                glyph.opacity(on ? 1 : 0.72)
            }
        } else {
            glyph
        }
    }
}

/// A ¾ arc that turns while a grab is in flight; still under Reduce Motion.
private struct LiveSpinner: View {
    let color: Color
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        let arc = Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 11, height: 11)
        if motion {
            RepeatForever(animation: .linear(duration: 0.9).repeatForever(autoreverses: false)) { on in
                arc.rotationEffect(.degrees(on ? 360 : 0))
            }
        } else {
            arc
        }
    }
}
