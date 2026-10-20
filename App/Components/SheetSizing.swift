import SwiftUI

// Sheet sizes and popovers that hold on every iPhone Duo pose (D4).
//
// - Folded, the outer display held sideways is only 466pt tall, so a plain
//   `.medium` detent leaves a sheet too short for a form and its keyboard.
// - Unfolded (regular width) height detents are ignored: a sheet is centred,
//   so the web's modals become form sheets and its popovers real popovers.

extension PresentationDetent {
    /// `.medium` on a phone held upright; the whole height when the container
    /// is short (the Duo's outer display sideways), where half would be about
    /// 220pt.
    static let mediumFitting = Self.custom(MediumFittingDetent.self)
}

private struct MediumFittingDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        context.maxDetentValue < 520 ? context.maxDetentValue : context.maxDetentValue * 0.5
    }
}

extension View {
    /// A centred form sheet at regular width, where the web shows a modal
    /// (rulings R3, R7; the Account panel, DC19). Compact width keeps the
    /// phone sheet and its detents.
    @ViewBuilder
    func formSheet(_ on: Bool = true) -> some View {
        if on {
            presentationSizing(.form)
        } else {
            self
        }
    }

    /// The web's popover at regular width (the Duo's inner display, an iPad),
    /// anchored on this control; today's phone sheet, with the content's own
    /// detents, whenever either dimension is compact (DC21).
    func sheetPopover<Content: View>(
        isPresented: Binding<Bool>,
        width: CGFloat = 360,
        height: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        popover(isPresented: isPresented) {
            content()
                // Ideal sizes size the popover; a sheet proposes its own size,
                // so they don't change the phone layout.
                .frame(idealWidth: width, idealHeight: height)
                .presentationCompactAdaptation(horizontal: .sheet, vertical: .sheet)
        }
    }
}
