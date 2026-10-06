import SwiftUI
import WidgetKit
import FusionhaKit

struct WidgetHeader: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(title).font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
        .widgetAccentable()
    }
}

struct WidgetSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct WidgetEmptyText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
