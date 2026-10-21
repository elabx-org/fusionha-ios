import SwiftUI
import FusionhaKit

// The login stages side by side (Login.module.css, DU15): past 760 the split
// layout's hero sits beside the form (`.splitGrid` 1.05fr 0.95fr), past 720
// the Living art does (`.livingGrid` 1.1fr 1fr). On a half-open Duo (Book) the
// columns meet at the fold, so the form keeps to one side of it (DC17). The
// art runs to the screen's edges; the form keeps clear of the side strip and
// the status bar (DC18).

extension SignInView {
    /// `.splitGrid`: the backdrop hero with the brand, then the form panel.
    var splitStageWide: some View {
        StageColumns(leadingShare: 1.05 / 2) {
            ZStack {
                SplitPanelFill.heroGround
                LoginBackdrop(mode: backdropMode, motionOff: motionOff)
                brand(hero: true)
                    .padding(40)
                    .loginEntrance(.riseIn(1.0), delay: 0.1)
            }
            .clipped()
            .ignoresSafeArea()
        } trailing: { size in
            sideFormPanel(size, hairline: nil)
        }
    }

    /// `.livingGrid`: the Living logo art, then the form panel with a hairline
    /// on its leading edge. The art is the same `LivingMark` (60 Hz timeline,
    /// its canvases drawn per frame), only in a column.
    var livingStageWide: some View {
        StageColumns(leadingShare: 1.1 / 2.1) {
            LivingMark(engine: living, reduce: motionOff,
                       backdrop: connected == nil && !look.cached ? .aurora : nil) {
                livingCaption
            }
            .ignoresSafeArea()
        } trailing: { size in
            sideFormPanel(size, hairline: .leading)
        }
    }

    /// The form panel as its own scrolling column, centred in the stage's height.
    private func sideFormPanel(_ size: CGSize, hairline: Edge?) -> some View {
        ScrollView {
            formPanel(top: false, minHeight: size.height, hairline: hairline)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background { SplitPanelFill().ignoresSafeArea() }
    }
}

/// Two columns: the leading one `leadingShare` of the width, the trailing one
/// the rest. When the Duo's fold runs top to bottom through the stage the
/// columns meet at it instead, with the fold itself left empty.
struct StageColumns<Leading: View, Trailing: View>: View {
    var leadingShare: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: (CGSize) -> Trailing

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldInfo(proxy)
            let lead = fold.verticalGap.map(\.lowerBound) ?? proxy.size.width * leadingShare
            let gap = fold.verticalGap.map { $0.upperBound - $0.lowerBound } ?? 0
            let trail = max(proxy.size.width - lead - gap, 0)
            HStack(spacing: gap) {
                leading.frame(width: lead, height: proxy.size.height)
                trailing(CGSize(width: trail, height: proxy.size.height))
                    .frame(width: trail, height: proxy.size.height)
            }
        }
    }
}
