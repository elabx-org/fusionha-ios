import SwiftUI

/// Lays its content out at exactly the width it is offered and reports that
/// width, whatever the content asks for: a vertical scroll view then never
/// sees content wider than itself, so it never centres (shifts) the page.
/// The content sits at the leading edge; anything wider runs off the trailing side.
struct PinnedWidthLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let size = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: proposal.height))
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height)
        )
    }
}

extension View {
    /// See `PinnedWidthLayout`.
    func pinnedToProposedWidth() -> some View {
        PinnedWidthLayout { self }
    }
}
