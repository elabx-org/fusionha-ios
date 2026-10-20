import SwiftUI
import FusionhaKit

func availSub(_ text: String) -> some View {
    Text(text).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
}

/// The bottom row of a tier card: tinted icon tile, title + one subline, action.
struct AvailRow<Icon: View, Action: View>: View {
    let tone: Color
    let icon: Icon
    let title: Text
    let sub: AnyView
    var shimmer = false
    let action: Action

    init(tone: Color, @ViewBuilder icon: () -> Icon, title: Text, sub: AnyView, shimmer: Bool = false,
         @ViewBuilder action: () -> Action) {
        self.tone = tone
        self.icon = icon()
        self.title = title
        self.sub = sub
        self.shimmer = shimmer
        self.action = action()
    }

    var body: some View {
        HStack(spacing: 10) {
            icon
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(tone)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                title
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .frame(height: 18)
                sub.frame(height: 18)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(tone.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { if shimmer { Color.clear.shimmer().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) } }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tone.opacity(0.18)))
    }
}

extension AvailRow where Action == EmptyView {
    init(tone: Color, @ViewBuilder icon: () -> Icon, title: Text, sub: AnyView, shimmer: Bool = false) {
        self.init(tone: tone, icon: icon, title: title, sub: sub, shimmer: shimmer) { EmptyView() }
    }
}
