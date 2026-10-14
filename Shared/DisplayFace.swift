import SwiftUI
import UIKit
import CoreText

/// The display face: Mona Sans, bundled as its unmodified variable font (its
/// licence reserves the name, so no static cut is made) and set to the
/// condensed width and a heavy weight through its `wdth` / `wght` axes.
/// Falls back to the system font, condensed, if the file is missing.
enum DisplayFace {
    private static let postScriptName = "MonaSans-ExtraLight"  // the variable font's default instance
    private static let wdth = 0x7764_7468  // 'wdth'
    private static let wght = 0x7767_6874  // 'wght'
    private static var cache: [String: UIFont] = [:]

    /// The face at `size` points, scaled for Dynamic Type relative to `style`.
    static func font(size: CGFloat, weight: CGFloat, style: Font.TextStyle) -> UIFont {
        let key = "\(size)-\(weight)-\(style)-\(UITraitCollection.current.preferredContentSizeCategory.rawValue)"
        if let hit = cache[key] { return hit }
        let base: UIFont
        if UIFont(name: postScriptName, size: size) != nil {
            let variation = [kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [wdth: 75, wght: weight]]
            let descriptor = UIFontDescriptor(name: postScriptName, size: size).addingAttributes(variation)
            base = UIFont(descriptor: descriptor, size: size)
        } else {
            let system = UIFont.systemFont(ofSize: size, weight: .heavy)
            base = system.fontDescriptor.withSymbolicTraits(.traitCondensed).map { UIFont(descriptor: $0, size: size) } ?? system
        }
        let scaled = UIFontMetrics(forTextStyle: style.uiKit).scaledFont(for: base)
        cache[key] = scaled
        return scaled
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}
