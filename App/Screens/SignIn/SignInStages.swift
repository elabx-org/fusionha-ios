import SwiftUI
import FusionhaKit

// The three login stages (Login.module.css `data-layout`). The backdrops run
// edge to edge; the form never sits under the status bar or the Duo's side
// strip (DC18), and on a half-open Duo it stays on one side of the fold (DC17).
// Past 760 (split) and 720 (living) of the stage's width the art sits beside
// the form (`SignInWideStages`, DU15).

extension SignInView {
    /// `[data-layout='centered']`: full-bleed backdrop + veil, the glass card
    /// centred in a 384pt column.
    var centeredStage: some View {
        ZStack {
            LoginBackdrop(mode: backdropMode, motionOff: motionOff)
                .ignoresSafeArea()
            FoldSafe { size in
                ScrollView {
                    VStack(spacing: 18) {
                        card
                        changeServer
                    }
                    .frame(maxWidth: 384)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, minHeight: size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    /// `[data-layout='split']`: the hero beside the form past 760, else stacked.
    @ViewBuilder var splitStage: some View {
        if SignInLayoutRule.splitSideBySide(width: Double(stageWidth)) {
            splitStageWide
        } else {
            splitStageStacked
        }
    }

    /// `[data-layout='split']` at phone width (`@media (max-width: 760px)`):
    /// one column, the animated hero (min 190pt) over the solid form panel;
    /// spare height is shared between the two rows like the CSS grid.
    private var splitStageStacked: some View {
        ZStack {
            VStack(spacing: 0) {
                SplitPanelFill.heroGround
                SplitPanelFill()
            }
            .ignoresSafeArea()
            FoldSafe { size in
                ScrollView {
                    StretchRows(minHeight: size.height) {
                        ZStack {
                            SplitPanelFill.heroGround
                            LoginBackdrop(mode: backdropMode, motionOff: motionOff)
                            brand(hero: true)
                                .padding(40)
                                .loginEntrance(.riseIn(1.0), delay: 0.1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 190)
                        .clipped()

                        formPanel(top: false)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            // The hero runs under the status bar; the sides stay clear (DC18).
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    /// `.formPanel`: the solid panel under the hero on phones, with a hairline
    /// on top; beside the art when wide (`hairline` on its leading edge, or none).
    func formPanel(top: Bool, minHeight: CGFloat = 0, hairline: Edge? = .top) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                header(centered: false)
                content
            }
            .disabled(working)
            .modifier(Nudge(trigger: nudges))
            changeServer
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: top ? .top : .center)
        .background(SplitPanelFill())
        .overlay(alignment: hairline == .leading ? .leading : .top) {
            if let hairline {
                Rectangle().fill(.white.opacity(0.08))
                    .frame(width: hairline == .leading ? 1 : nil, height: hairline == .leading ? nil : 1)
            }
        }
    }

    /// `[data-layout='living']` on phones: the Living logo art takes the top 44%
    /// of the screen and the form sits below it (its own dot field, so
    /// `login_background` does not apply). Only the wordmark/tagline toggles
    /// apply under the mark: the mark IS the logo. Before any server is known
    /// (a fresh install) the default backdrop runs behind the mark instead.
    var livingStage: some View {
        Group {
            if SignInLayoutRule.livingSideBySide(width: Double(stageWidth)) {
                livingStageWide
            } else {
                livingStageStacked
            }
        }
        .onChange(of: password) { if isLiving { living.typing(password.count) } }
        .onChange(of: server) { if isLiving, connected == nil { living.typing(server.count) } }
        .onChange(of: field) { old, new in
            guard isLiving else { return }
            let listens: Set<Field> = [.password, .server]
            if let new, listens.contains(new) {
                living.listen()
            } else if let old, listens.contains(old) {
                living.unlisten()
            }
        }
    }

    private var livingStageStacked: some View {
        ZStack {
            VStack(spacing: 0) {
                Color(hex: 0x08090D)
                SplitPanelFill()
            }
            .ignoresSafeArea()
            FoldSafe { size in
                ScrollView {
                    VStack(spacing: 0) {
                        LivingMark(engine: living, reduce: motionOff,
                                   backdrop: connected == nil && !look.cached ? .aurora : nil) {
                            livingCaption
                        }
                        .frame(height: size.height * 0.44)
                        // `place-items: start center` under the art.
                        formPanel(top: true, minHeight: size.height * 0.56)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            // The art runs under the status bar; the sides stay clear (DC18).
            .ignoresSafeArea(.container, edges: .top)
        }
    }
}

/// The split / living form panel's solid fill.
struct SplitPanelFill: View {
    /// The split hero's ground (`.hero` #0b0d13): the login stage is always dark.
    static let heroGround = Color(hex: 0x0B0D13)

    var body: some View {
        LinearGradient(colors: [Color(red: 19 / 255, green: 21 / 255, blue: 28 / 255).opacity(0.98),
                                Color(red: 12 / 255, green: 13 / 255, blue: 18 / 255).opacity(0.99)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Lays its content out in the largest part of the container that the Duo's
/// fold doesn't cross (the whole container when there is no fold), so a
/// centred card or form never sits on the hinge.
struct FoldSafe<Content: View>: View {
    @ViewBuilder var content: (CGSize) -> Content

    var body: some View {
        GeometryReader { proxy in
            let region = Self.region(FoldInfo(proxy))
            content(region.size)
                .frame(width: region.width, height: region.height)
                .position(x: region.midX, y: region.midY)
        }
    }

    static func region(_ fold: FoldInfo) -> CGRect {
        let full = CGRect(origin: .zero, size: fold.size)
        if let x = fold.verticalGap {
            let leading = CGRect(x: 0, y: 0, width: x.lowerBound, height: full.height)
            let trailing = CGRect(x: x.upperBound, y: 0, width: full.width - x.upperBound, height: full.height)
            return leading.width >= trailing.width ? leading : trailing
        }
        if let y = fold.horizontal {
            let top = CGRect(x: 0, y: 0, width: full.width, height: y.lowerBound)
            let bottom = CGRect(x: 0, y: y.upperBound, width: full.width, height: full.height - y.upperBound)
            return top.height >= bottom.height ? top : bottom
        }
        return full
    }
}
