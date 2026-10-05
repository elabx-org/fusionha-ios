import SwiftUI
import WidgetKit

/// The widgets' background: the app's dark panel (the system swaps it out in
/// the accented and clear renderings).
extension View {
    func fusionhaWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(colors: [Theme.panel, Theme.bg], startPoint: .top, endPoint: .bottom)
        }
    }
}
