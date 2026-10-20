import SwiftUI
import FusionhaKit

/// The Library pulse inline past 720 (LibraryPulse.tsx desktop ribbon, ruling
/// L17): one solid card (content, never glass) with the status pills beside
/// the three meters (1.15 : 1), then the kinds row. On a phone the pills and
/// meters live in the Library stats sheet instead.
struct LibraryPulseRibbon: View {
    let derived: LibraryDerived
    @Binding var status: LibraryStatus
    @Binding var kind: String
    @Environment(\.motionEnabled) private var motion
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RibbonColumns(spacing: 18, leadingShare: 1.15 / 2.15) {
                LibraryWrap(spacing: 8) {
                    ForEach(LibraryPulseParts.order, id: \.0) { entry in
                        PulseStatButton(key: entry.0, label: entry.1, pulse: derived.pulse, status: $status)
                    }
                }
                PulseMeters(pulse: derived.pulse, grown: grown)
            }
            LibraryKindsBar(derived: derived, kind: $kind)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library summary")
        .onAppear {
            withAnimation(motion ? Motion.reveal(1.1) : nil) { grown = true }
        }
    }
}

/// Two columns sharing the width like the ribbon's `grid-template-columns:
/// 1.15fr 1fr`, each vertically centred in the taller one's height.
private struct RibbonColumns: Layout {
    var spacing: CGFloat
    var leadingShare: CGFloat

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let free = max(total - spacing, 0)
        return (free * leadingShare, free * (1 - leadingShare))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 600
        let (a, b) = widths(total)
        let heights = zip(subviews, [a, b]).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
        return CGSize(width: total, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = widths(bounds.width)
        var x = bounds.minX
        for (view, width) in zip(subviews, [a, b]) {
            let height = view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            view.place(at: CGPoint(x: x, y: bounds.midY - height / 2), proposal: ProposedViewSize(width: width, height: height))
            x += width + spacing
        }
    }
}
