import SwiftUI
import FusionhaKit

// MARK: - Login screen pieces

/// The live preview (`.preview`): the chosen backdrop behind a wireframe of the
/// login, centered card or split hero + form side, reflecting the toggles.
struct LoginPreview: View {
    let layout: String
    let background: BackdropMode
    let motionOff: Bool
    let showLogo: Bool
    let showWordmark: Bool
    let showTagline: Bool

    private static let cardFill = LinearGradient(
        colors: [Color(red: 23 / 255, green: 26 / 255, blue: 35 / 255).opacity(0.82),
                 Color(red: 17 / 255, green: 19 / 255, blue: 26 / 255).opacity(0.9)],
        startPoint: .top, endPoint: .bottom)
    private static let formFill = LinearGradient(
        colors: [Color(red: 20 / 255, green: 22 / 255, blue: 29 / 255).opacity(0.97),
                 Color(red: 13 / 255, green: 14 / 255, blue: 19 / 255).opacity(0.99)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                Theme.panel
                if layout == "living" {
                    LivingDots(spacing: 9, radius: 0.8, alpha: 0.22)
                } else {
                    BackdropCanvas(mode: background, motionOff: motionOff)
                }
                CSSRadialGradient.previewVeil
                if layout == "living" {
                    HStack(spacing: 0) {
                        VStack(spacing: 10) {
                            FloatingMark(motionOff: motionOff)
                            if showWordmark {
                                Text("FUSIONHA")
                                    .font(.system(size: 11))
                                    .tracking(11 * 0.28)
                                    .foregroundStyle(Theme.txt)
                            }
                            if showTagline {
                                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06))
                                    .frame(width: (width * 0.52) * 0.72, height: 6)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 9) {
                            bar.frame(width: max(0, (width * 0.48 - 44) * 0.45))
                            bar
                            bar
                            button
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 26)
                        .frame(width: max(150, width * 0.48))
                        .frame(maxHeight: .infinity)
                        .background(LinearGradient(colors: [Color(hex: 0x12141B), Color(hex: 0x0D0E13)],
                                                   startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                    }
                } else if layout == "split" {
                    let formWidth = min(190, max(150, width / 2))
                    HStack(spacing: 0) {
                        VStack(spacing: 10) {
                            brand(dot: 44, taglineWidth: (width - formWidth) * 0.72)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 9) {
                            bar.frame(width: (formWidth - 44) * 0.45)
                            bar
                            bar
                            button
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 26)
                        .frame(width: formWidth)
                        .frame(maxHeight: .infinity)
                        .background(Self.formFill)
                        .shadow(color: .black.opacity(0.85), radius: 30, x: -30)
                    }
                } else {
                    VStack(spacing: 9) {
                        brand(dot: 34, taglineWidth: 164 * 0.72)
                        bar
                        bar
                        button
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .frame(width: 200)
                    .background(Self.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
                    .shadow(color: .black.opacity(0.7), radius: 25, y: 20)
                }
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Login preview")
    }

    @ViewBuilder
    private func brand(dot: CGFloat, taglineWidth: CGFloat) -> some View {
        if showLogo {
            Circle()
                .fill(Theme.fusion)
                .frame(width: dot, height: dot)
        }
        if showWordmark {
            Text("FUSIONHA")
                .font(.system(size: 11))
                .tracking(11 * 0.28)
                .foregroundStyle(Theme.txt)
        }
        if showTagline {
            RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)).frame(width: taglineWidth, height: 6)
        }
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.09)).frame(height: 9)
    }

    private var button: some View {
        RoundedRectangle(cornerRadius: 5).fill(Theme.fusion).frame(height: 11).padding(.top, 2)
    }
}
