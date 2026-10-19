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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let active = item.value == selection
                    Button {
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
            .padding(4)
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: histChip (filter chip with a top accent bar when active)

struct ActChip: View {
    let label: String
    var count: Int?
    let accent: Color
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(label)
                if let count {
                    Text("\(count)")
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(selected ? Theme.txt : Theme.dim)
                }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(selected ? Theme.txt : Theme.mut)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? Theme.panel2 : Theme.panel)
            .overlay(alignment: .top) {
                if selected { Rectangle().fill(accent).frame(height: 2) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: SegmentedControl

struct ActSegment<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var segment
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let label = options[index].1
                let active = value == selection
                Button {
                    if reduce { selection = value } else { withAnimation(.snappy(duration: 0.22)) { selection = value } }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(active ? ActColor.segText : Theme.mut)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.indigo.opacity(0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.indigo.opacity(0.5)))
                                    .matchedGeometryEffect(id: "segment", in: segment)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(ActColor.segTrack, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: ListSearch

struct ActSearch: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Theme.dim)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.dim))
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(Theme.mut)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .glassEffect(focused ? .regular.tint(Theme.txt.opacity(0.10)).interactive() : .regular.interactive(),
                     in: Capsule())
    }
}

// MARK: OverviewStrip

struct ActOverview: View {
    struct Stat: Identifiable {
        let label: String
        let value: Int
        let color: Color
        var id: String { label }
    }

    let total: Int
    let label: String
    let stats: [Stat]

    var body: some View {
        let maxValue = max(stats.map(\.value).max() ?? 0, 1)
        // Mobile web: the total sits on its own row, the per-state stats wrap beneath it.
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(total)").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(Theme.txt)
                label10(label)
            }
            ActFlow(spacing: 20, lineSpacing: 12) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(stat.value)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.txt)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.txt.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2).fill(stat.color)
                                .frame(width: geo.size.width * CGFloat(stat.value) / CGFloat(maxValue))
                        }
                    }
                    .frame(height: 3)
                    label10(stat.label)
                }
                .frame(minWidth: 74, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
            }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func label10(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(Theme.dim)
            .lineLimit(1)
    }
}

// MARK: EmptyState

struct ActEmpty: View {
    let message: String
    var quip: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 13.5))
                .lineSpacing(13.5 * 0.6 / 2)
                .foregroundStyle(Theme.mut)
            if let quip {
                Text("— \(quip)").font(.system(size: 13)).italic().foregroundStyle(Theme.dim)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

// MARK: Section header (`.section`): sentence case, 20pt, a quiet count

struct ActSection: View {
    let title: String
    let count: Int?
    var hint: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .accessibilityAddTraits(.isHeader)
            if let count {
                Text("\(count)")
                    .font(.system(size: 17).monospacedDigit())
                    .foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 0)
            if let hint {
                Text(hint).font(.system(size: 13)).foregroundStyle(Theme.dim).lineLimit(1)
            }
        }
    }
}
