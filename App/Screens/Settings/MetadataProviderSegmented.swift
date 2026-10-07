import SwiftUI

/// Settings › Metadata › Default provider (the web's
/// `MetadataProviderSegmented`): a logo-carrying segmented control. TMDB, TVDB
/// and TVmaze are logo-only (the wordmark is the name); Hybrid is its ring mark
/// beside the word. Four across on a wide screen, 2 × 2 on a phone, like the
/// web. A native segmented `Picker` can't show the chips or the drawn mark.
///
/// Options in `disabled` stay visible but dimmed and can't be picked (TVDB and
/// Hybrid without a TVDB key); the current value keeps its active look even
/// when disabled.
struct MetadataProviderSegmented: View {
    @Binding var selection: String
    var disabled: Set<String> = []
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.motionEnabled) private var motion
    @Namespace private var indicator

    private static let options: [(value: String, label: String)] = [
        ("tmdb", "TMDB"), ("tvdb", "TVDB"), ("tvmaze", "TVmaze"), ("hybrid", "Hybrid"),
    ]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: sizeClass == .compact ? 2 : 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.options, id: \.value) { option in
                segment(option.value, label: option.label)
            }
        }
        .padding(6)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Default provider")
    }

    private func segment(_ value: String, label: String) -> some View {
        let active = value == selection
        let locked = disabled.contains(value)
        return Button {
            guard !locked else { return }
            withAnimation(motion ? Motion.indicator : nil) { selection = value }
        } label: {
            ProviderMark(provider: value, size: 16)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(active ? Theme.txt : Theme.mut)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                            .shadow(color: .black.opacity(0.25), radius: 0, y: 2)
                            .matchedGeometryEffect(id: "segment", in: indicator)
                    }
                }
                .opacity(locked ? (active ? 0.7 : 0.45) : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityHint(locked ? "Needs a TVDB key" : "")
    }
}
