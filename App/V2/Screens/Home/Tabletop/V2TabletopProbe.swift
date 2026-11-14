import SwiftUI

/// TEMPORARY (slice 3 diagnosis): CI's `FUSIONHA_SCREENSHOT_TABLETOP_PROBE`
/// prints the tabletop page's geometry over it and picks a layout variant.
enum V2TabletopProbe {
    static let variant: String? = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_PROBE"]
        #else
        return nil
        #endif
    }()
}

extension View {
    @ViewBuilder
    func v2TabletopProbe(top: CGFloat, space: V2TabletopSpace) -> some View {
        if V2TabletopProbe.variant != nil {
            overlay {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    let safe = proxy.safeAreaInsets
                    Text(String(format: "probe %@ | frame y %.1f h %.1f | safe t %.1f b %.1f | top %.1f | space h %.1f fold %.1f",
                                V2TabletopProbe.variant ?? "", frame.minY, frame.height, safe.top, safe.bottom,
                                top, space.size.height, space.fold.lowerBound))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .padding(6)
                        .background(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}
