import SwiftUI

/// CI screenshots only: v2's own galleries, reached from the shared
/// `AppSceneContent` (v2's files are not in v1's target, so v1 gets nil).
enum V2GalleryHost {
    static var view: AnyView? {
        #if V2
        V2WidgetGalleryView.screenshotVariant.map { AnyView(V2WidgetGalleryView(variant: $0)) }
        #else
        nil
        #endif
    }
}
