import SwiftUI
import UIKit

/// Diagonal white stripes sliding along a downloading fill (`seasonBarStripe`,
/// 18px period, 0.85s). One stripe period is drawn once into a pattern tile
/// and slid by a Core Animation animation, so it runs in the render server:
/// the old 30 fps `TimelineView` + `Canvas` re-ran the view graph and redrew
/// on the main thread, and on the open Duo it did that beside a scrolling
/// Library on the other page.
struct DetailStripes: View {
    @Environment(\.detailReduceMotion) private var reduce

    var body: some View {
        StripesLayerView(color: UIColor(Theme.sweep.opacity(0.28)), moving: !reduce)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct StripesLayerView: UIViewRepresentable {
    let color: UIColor
    let moving: Bool

    func makeUIView(context: Context) -> StripesView { StripesView() }

    func updateUIView(_ view: StripesView, context: Context) {
        view.configure(color: color, moving: moving)
    }
}

final class StripesView: UIView {
    static let period: CGFloat = 18
    private let band = CALayer()
    private var color: UIColor = .clear
    private var moving = true
    private var tileHeight: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(band)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(color: UIColor, moving: Bool) {
        guard color != self.color || moving != self.moving else { return }
        self.color = color
        self.moving = moving
        tileHeight = -1
        setNeedsLayout()
    }

    // Back on screen (a page that returns), the slide restarts.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        guard h > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        band.frame = CGRect(x: -Self.period, y: 0, width: bounds.width + Self.period * 2, height: h)
        if h != tileHeight {
            tileHeight = h
            band.backgroundColor = UIColor(patternImage: Self.tile(height: h, color: color)).cgColor
        }
        CATransaction.commit()
        if moving, band.animation(forKey: "slide") == nil {
            let slide = CABasicAnimation(keyPath: "transform.translation.x")
            slide.fromValue = 0
            slide.toValue = Self.period
            slide.duration = 0.85
            slide.repeatCount = .infinity
            slide.isRemovedOnCompletion = false
            band.add(slide, forKey: "slide")
        } else if !moving {
            band.removeAnimation(forKey: "slide")
        }
    }

    /// One period: the stripes (6 wide, leaning 45°) that cross an 18-wide
    /// column of this height, as the Canvas drew them.
    private static func tile(height h: CGFloat, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: period, height: h)).image { _ in
            color.setFill()
            var x = -h - period
            while x < period * 2 {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: h))
                path.addLine(to: CGPoint(x: x + h, y: 0))
                path.addLine(to: CGPoint(x: x + h + 6, y: 0))
                path.addLine(to: CGPoint(x: x + 6, y: h))
                path.close()
                path.fill()
                x += period
            }
        }
    }
}
