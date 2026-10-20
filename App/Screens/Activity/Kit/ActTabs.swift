import SwiftUI
import FusionhaKit

// MARK: Tabs (Tabs.module.css): a glass capsule, horizontally scrolling on
// mobile; the active tab is a solid cream pill (the house lights).

struct ActTabs<Value: Hashable>: View {
    struct Item {
        let value: Value
        let label: String
        var badge: Int = 0
        var badgeColor: Color = Theme.grab
        /// Max-contrast ink for the badge fill (black or white by luminance).
        var badgeInk: Color = Theme.onFill(hex: Theme.palette.grab)
    }

    let items: [Item]
    @Binding var selection: Value
    /// Pass a shared namespace when the strip is rebuilt per page, so the indicator still slides.
    var namespace: Namespace.ID? = nil
    @Namespace private var indicator
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(items.indices, id: \.self) { index in
                        tab(items[index]).id(items[index].value)
                    }
                }
                .padding(4)
            }
            // The selected tab stays in view: on appear, when it changes, and
            // when the strip's width changes (fold, unfold, rotation).
            .onAppear { reveal(proxy, animated: false) }
            .onChange(of: selection) { reveal(proxy, animated: !reduce) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _ in
                reveal(proxy, animated: false)
            }
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func reveal(_ proxy: ScrollViewProxy, animated: Bool) {
        let target = selection
        // After this pass's layout, so the strip has its content size.
        DispatchQueue.main.async {
            if animated {
                withAnimation(.snappy(duration: 0.25)) { proxy.scrollTo(target, anchor: .center) }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func tab(_ item: Item) -> some View {
        let active = item.value == selection
        return Button {
            if reduce { selection = item.value } else {
                withAnimation(.snappy(duration: 0.25)) { selection = item.value }
            }
        } label: {
            HStack(spacing: 6) {
                Text(item.label)
                if item.badge > 0 {
                    Text("\(item.badge)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(item.badgeInk)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(item.badgeColor, in: Capsule())
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(active ? Theme.onInk : Theme.mut)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background {
                if active {
                    Capsule().fill(Theme.txt)
                        .matchedGeometryEffect(id: "tab-indicator", in: namespace ?? indicator)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
