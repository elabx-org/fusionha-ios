import UIKit
import SwiftUI
import FusionhaKit

// The web's shared Activity / Wanted primitives (Tabs, histChip, ListSearch,
// SegmentedControl, OverviewStrip, EmptyState, GroupCard, StatusWash,
// InfiniteScrollFooter, BulkBar, toasts), sized 1:1 from the web CSS. Prefixed
// `Act` so they never collide with the shared WebUI components.

// MARK: Colours

enum ActColor {
    /// `#111319`, the SegmentedControl group fill.
    static let segTrack = Color(hex: 0x111319)
    /// `mix(--i2 45%, --txt)`, the SegmentedControl active text.
    static let segText = Color(hex: 0x90E0EF)
}

// MARK: Status wash (StatusWash.module.css)

extension View {
    /// The ambient left-edge tint: `linear-gradient(90deg, mix(c 13%, --card) 0%, --card 42%)`.
    func actWash(_ color: Color?, radius: CGFloat = 14, base: Color = Theme.card, border: Color = Theme.line) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(base)
                .overlay {
                    if let color {
                        LinearGradient(stops: [.init(color: color.opacity(0.13), location: 0),
                                               .init(color: color.opacity(0), location: 0.42)],
                                       startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border))
    }
}

// MARK: Poster

enum ActPosterSize {
    case sm, md, lg
    var size: CGSize {
        switch self {
        case .sm: return CGSize(width: 30, height: 45)
        case .md: return CGSize(width: 36, height: 54)
        case .lg: return CGSize(width: 48, height: 72)
        }
    }
    var radius: CGFloat { self == .sm ? 6 : (self == .md ? 7 : 8) }
}

struct ActPoster: View {
    let url: String?
    let title: String
    var size: ActPosterSize = .md

    var body: some View {
        PosterImage(url: TMDBImage.resized(url, to: "w154"))
            .overlay {
                if url == nil {
                    Text(String(title.prefix(1)).uppercased())
                        .font(.system(size: size == .sm ? 11 : 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.mut)
                }
            }
            .frame(width: size.size.width, height: size.size.height)
            .clipShape(RoundedRectangle(cornerRadius: size.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size.radius, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
            .accessibilityHidden(true)
    }
}

// MARK: Flow layout (wrapping chip rows)

struct ActFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = alignment == .trailing ? bounds.maxX - row.width : bounds.minX
            for index in row.indices {
                let size = measure(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    /// Natural size, but a subview wider than the line wraps to the line width instead of overflowing.
    private func measure(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard width.isFinite, natural.width > width else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = measure(subviews[index], width: width)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: Tabs (Tabs.module.css) — horizontally scrolling on mobile

struct ActTabs<Value: Hashable>: View {
    struct Item {
        let value: Value
        let label: String
        var badge: Int = 0
        var badgeColor: Color = Theme.grab
    }

    let items: [Item]
    @Binding var selection: Value
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
                                    .foregroundStyle(Color(hex: 0x04121A))
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(item.badgeColor, in: Capsule())
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? Theme.txt : Theme.mut)
                        .padding(.horizontal, 13)
                        .frame(height: 30)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.panel)
                                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                                    .matchedGeometryEffect(id: "tab-indicator", in: indicator)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(3)
        }
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
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
                    Text("✕").font(.system(size: 13)).foregroundStyle(Theme.mut).frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(focused ? Theme.cyan.opacity(0.55) : Theme.line))
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Theme.cyan.opacity(focused ? 0.13 : 0), lineWidth: 3))
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
            .font(.system(size: 10, weight: .bold))
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

// MARK: Section header (`.section`)

struct ActSection: View {
    let title: String
    let count: Int?
    var hint: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.mut)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.dim)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(Theme.panel2, in: Capsule())
            }
            Spacer(minLength: 0)
            if let hint {
                Text(hint).font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
            }
        }
    }
}

// MARK: Buttons (Button.module.css)

enum ActButtonKind { case primary, subtle, ghost, danger, warn, amber }

struct ActButtonStyle: ButtonStyle {
    var kind: ActButtonKind = .subtle
    var small = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: small ? 12 : 13, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, small ? 11 : 14)
            .frame(minHeight: small ? 30 : 36)
            .foregroundStyle(foreground)
            .background { background }
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(border)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.bg
        case .subtle: return Theme.txt
        case .ghost: return Theme.mut
        case .danger: return Theme.danger
        case .warn: return Theme.miss
        case .amber: return Color(hex: 0x1A1206)
        }
    }

    private var border: Color? {
        switch kind {
        case .danger: return Theme.danger.opacity(0.4)
        case .warn: return Theme.miss.opacity(0.45)
        case .subtle: return Theme.line
        default: return nil
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .primary: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.fusion)
        case .subtle: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.panel)
        case .amber: RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.miss)
        default: Color.clear
        }
    }
}

/// The 26pt `.iact` / `.ib` row action button (40pt tap target).
struct ActIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = Theme.mut
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().controlSize(.mini).tint(tint)
                } else {
                    Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(tint == Theme.mut ? Color.clear : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// The `⋯` ActionMenu trigger (native Menu, CLAUDE.md: native controls).
struct ActMoreMenu<Content: View>: View {
    var label = "More actions"
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.dim)
                .frame(width: 26, height: 26)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: Chips

/// The queue `TierChip`: mono 9/700, `HD·1080p` / `UHD·4K`.
struct ActTierChip: View {
    let tier: QualityTier
    var big = false

    var body: some View {
        Text(big ? tier.rawValue : tier.chipLabel)
            .font(.system(size: big ? 10 : 9, weight: .bold, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, big ? 7 : 5)
            .padding(.vertical, 1)
            .background(tier.color.opacity(big ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: big ? 6 : 4))
            .overlay(RoundedRectangle(cornerRadius: big ? 6 : 4).strokeBorder(tier.color.opacity(0.4)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// `QualityChip`: mono 10/700, tinted by the quality's tier.
struct ActQualityChip: View {
    let quality: String

    var body: some View {
        let tint: Color = quality.contains("2160") ? Theme.grab : (quality.contains("1080") ? Theme.edition : Theme.mut)
        Text(ActFmt.quality(quality))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.3)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// A small mono meta chip (panel2, r6).
struct ActMonoChip: View {
    let text: String
    var color: Color = Theme.mut
    var border: Color = Theme.line
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9)) }
            Text(text)
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 1)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(border))
        .lineLimit(1)
        .fixedSize()
    }
}

/// `ProvenanceChip` (grab_trigger).
struct ActProvenance: View {
    let trigger: String

    var body: some View {
        if let meta = Self.meta(trigger) {
            HStack(spacing: 4) {
                Image(systemName: meta.icon).font(.system(size: 10))
                Text(meta.label)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(meta.color)
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(meta.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(meta.color.opacity(0.25)))
            .lineLimit(1)
            .fixedSize()
        }
    }

    static func meta(_ trigger: String) -> (label: String, icon: String, color: Color)? {
        switch trigger.lowercased() {
        case "rss": return ("RSS", "dot.radiowaves.up.forward", Theme.dim)
        case "search": return ("Search", "magnifyingglass", Theme.dim)
        case "upgrade": return ("Upgrade", "arrow.up", Theme.dim)
        case "interactive": return ("Interactive", "person", Theme.indigo)
        case "forced": return ("Forced", "bolt", Theme.indigo)
        case "regrab": return ("Re-grabbed", "arrow.clockwise", Theme.indigo)
        case "requested", "request": return ("Requested", "tray.and.arrow.down", Theme.edition)
        default: return nil
        }
    }
}

// MARK: Select checkbox + bulk bar

struct ActCheckbox: View {
    let checked: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(checked ? AnyShapeStyle(Theme.fusion) : AnyShapeStyle(Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(checked ? Color.clear : Theme.mut, lineWidth: 1.5))
            .overlay {
                if checked { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white) }
            }
            .frame(width: 18, height: 18)
            .accessibilityLabel(checked ? "Selected" : "Not selected")
    }
}

extension View {
    /// The selected-row treatment: indigo border + 6% indigo fill.
    func actSelected(_ on: Bool, radius: CGFloat = 14) -> some View {
        overlay {
            if on {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.indigo.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.indigo.opacity(0.45)))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// The sticky glass bulk-action bar (`.bulkbar`).
struct ActBulkBar<Actions: View>: View {
    let count: Int
    var hint: String?
    let onSelectAll: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                (Text("\(count)").foregroundColor(Theme.cyan).bold() + Text(" selected"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                Button("Select all", action: onSelectAll)
                    .buttonStyle(ActButtonStyle(kind: .ghost))
                Spacer(minLength: 0)
            }
            ActFlow(spacing: 8, lineSpacing: 8) { actions }
            if let hint {
                Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.indigo.opacity(0.4)))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

// MARK: Infinite scroll footer

struct ActFooter: View {
    let total: Int
    let loaded: Int
    let hasMore: Bool
    let loading: Bool
    let noun: String
    var query: String = ""
    let loadMore: () -> Void

    var body: some View {
        Group {
            if loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(Theme.cyan)
                    Text("Loading more…")
                }
            } else if hasMore {
                HStack(spacing: 10) {
                    Button(action: loadMore) {
                        HStack(spacing: 8) {
                            Text("Load more").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text("\(loaded) of \(total)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
                    }
                    .buttonStyle(.plain)
                }
                .onAppear(perform: loadMore)
            } else if total > 0 {
                HStack(spacing: 8) {
                    hairline
                    (Text("You’ve reached the end").bold().foregroundColor(Theme.mut)
                     + Text(" · showing all ")
                     + Text("\(total)").font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.cyan)
                     + Text(" \(noun)")
                     + Text(query.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " matching “\(query.trimmingCharacters(in: .whitespaces))”"))
                        .multilineTextAlignment(.center)
                    hairline
                }
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.dim)
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }

    private var hairline: some View {
        LinearGradient(colors: [Theme.indigo.opacity(0), Theme.cyan.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34, height: 1)
    }
}

// MARK: GroupCard

struct ActGroupCard<PosterV: View, TitleV: View, TrailingV: View, BodyV: View>: View {
    var wash: Color?
    var base: Color = Theme.panel
    var hasTrailing = true
    @State private var open: Bool
    @Environment(\.actReduceMotion) private var reduceMotion
    private let poster: PosterV
    private let title: TitleV
    private let trailing: TrailingV
    private let content: BodyV

    init(wash: Color? = nil, base: Color = Theme.panel, defaultOpen: Bool = true, hasTrailing: Bool = true,
         @ViewBuilder poster: () -> PosterV, @ViewBuilder title: () -> TitleV,
         @ViewBuilder trailing: () -> TrailingV, @ViewBuilder content: () -> BodyV) {
        self.wash = wash
        self.base = base
        self.hasTrailing = hasTrailing
        _open = State(initialValue: defaultOpen)
        self.poster = poster()
        self.title = title()
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    poster
                    title.frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if reduceMotion { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.dim)
                            .rotationEffect(.degrees(open ? 90 : 0))
                            .frame(width: 26, height: 26)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -6)
                    .padding(.trailing, -6)
                    .accessibilityLabel(open ? "Collapse" : "Expand")
                }
                if hasTrailing {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        trailing
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    content
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .actWash(wash, radius: 14, base: base)
    }
}

// MARK: Toasts

@MainActor
@Observable
final class ActToaster {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        var tone: Tone = .info
        var undoLabel: String?
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    enum Tone { case info, success, warning, error }

    private(set) var current: Toast?
    private var undo: (() -> Void)?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, tone: Tone = .info, undoLabel: String? = nil, undo: (() -> Void)? = nil) {
        current = Toast(text: text, tone: tone, undoLabel: undo == nil ? nil : (undoLabel ?? "Undo"))
        self.undo = undo
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(undo == nil ? 3.5 : 6))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func error(_ error: Error, fallback: String? = nil) {
        if let api = error as? APIError, let message = api.serverDetail {
            show(message, tone: .error)
        } else {
            show(fallback ?? error.localizedDescription, tone: .error)
        }
    }

    func runUndo() {
        let action = undo
        undo = nil
        current = nil
        action?()
    }

    func dismiss() { current = nil }
}

struct ActToastOverlay: View {
    let toaster: ActToaster
    @Environment(\.actReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            if let toast = toaster.current {
                HStack(spacing: 10) {
                    Circle().fill(color(toast.tone)).frame(width: 7, height: 7)
                    Text(toast.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let undo = toast.undoLabel {
                        Button(undo) { toaster.runUndo() }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.cyan)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .onTapGesture { toaster.dismiss() }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: toaster.current)
        .allowsHitTesting(toaster.current != nil)
    }

    private func color(_ tone: ActToaster.Tone) -> Color {
        switch tone {
        case .info: return Theme.cyan
        case .success: return Theme.done
        case .warning: return Theme.miss
        case .error: return Theme.danger
        }
    }
}

// MARK: Confirm dialog (mobile Dialog as a bottom sheet)

struct ActDialog<Options: View>: View {
    let title: String
    let message: String
    let confirmLabel: String
    var confirmKind: ActButtonKind = .danger
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ViewBuilder var options: Options

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            Text(message)
                .font(.system(size: 13))
                .lineSpacing(13 * 0.5 / 2)
                .foregroundStyle(Theme.mut)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) { options }
                .padding(.top, 16)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel).buttonStyle(ActButtonStyle(kind: .subtle, small: false))
                Button(action: onConfirm) {
                    HStack(spacing: 6) {
                        if busy { ProgressView().controlSize(.mini) }
                        Text(confirmLabel).lineLimit(2).multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(ActButtonStyle(kind: confirmKind, small: false))
                .disabled(busy)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }
}

/// A dialog option row: native toggle + optional hint.
struct ActOption: View {
    let label: String
    var hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13)).foregroundStyle(Theme.txt)
                if let hint { Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut) }
            }
        }
        .tint(Theme.indigo)
    }
}

// MARK: Formatting (lib/format)

enum ActFmt {
    static func date(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        if iso.count == 10 { return Format.day(iso) }
        if let d = Format.timestamp(iso) { return d }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: iso) { return d }
        // Naive UTC with any fraction length.
        let p = DateFormatter()
        p.locale = Locale(identifier: "en_US_POSIX")
        p.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            p.dateFormat = format
            if let d = p.date(from: iso) { return d }
        }
        return nil
    }

    /// The web's `relativeTime`: "just now", "5 minutes ago", "3 days ago".
    static func relative(_ iso: String?, now: Date = Date()) -> String {
        guard let d = date(iso) else { return "" }
        return relative(d, now: now)
    }

    static func relative(_ d: Date, now: Date = Date()) -> String {
        let secs = now.timeIntervalSince(d)
        let future = secs < 0
        let s = abs(secs)
        if s < 45 { return "just now" }
        func phrase(_ n: Int, _ unit: String) -> String {
            let text = "\(n) \(unit)\(n == 1 ? "" : "s")"
            return future ? "in \(text)" : "\(text) ago"
        }
        let mins = Int((s / 60).rounded())
        if mins < 60 { return phrase(max(mins, 1), "minute") }
        let hours = Int((s / 3600).rounded())
        if hours < 24 { return phrase(hours, "hour") }
        let days = Int((s / 86400).rounded())
        if days < 7 { return phrase(days, "day") }
        if days < 30 { return phrase(days / 7, "week") }
        if days < 365 { return phrase(max(days / 30, 1), "month") }
        return phrase(days / 365, "year")
    }

    /// "Oct 4 · 03:52".
    static func dateTime(_ iso: String?) -> String {
        guard let d = date(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d · HH:mm"
        return f.string(from: d)
    }

    /// "15 Mar 2009".
    static func releaseDate(_ iso: String?) -> String {
        guard let d = date(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: d)
    }

    static func bytes(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = value
        var i = 0
        while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
        return i == 0 ? "\(Int(v)) B" : String(format: "%.1f %@", v, units[i])
    }

    static func rate(_ bps: Double) -> String {
        guard bps > 0, bps.isFinite else { return "—" }
        let mb = bps / (1024 * 1024)
        if mb >= 1 { return mb >= 100 ? "\(Int(mb.rounded())) MB/s" : String(format: "%.1f MB/s", mb) }
        return "\(max(1, Int((bps / 1024).rounded()))) KB/s"
    }

    static func mbps(_ bps: Double) -> String {
        guard bps > 0, bps.isFinite else { return "0.0" }
        return String(format: "%.1f", bps / (1024 * 1024))
    }

    static func etaShort(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(Int(seconds.rounded()))s" }
        let mins = Int((seconds / 60).rounded())
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func etaApprox(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "—" }
        if seconds < 60 { return "<1 min" }
        let mins = Int((seconds / 60).rounded())
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func countdown(_ iso: String?, now: Date = Date()) -> String {
        guard let d = date(iso) else { return "—" }
        let remaining = Int(d.timeIntervalSince(now).rounded())
        if remaining <= 0 { return "due now" }
        if remaining < 3600 { return "in \(remaining / 60):\(String(format: "%02d", remaining % 60))" }
        return "in \(remaining / 3600)h \(String(format: "%02d", (remaining % 3600) / 60))m"
    }

    private static let qualityLabels: [String: String] = [
        "REMUX_2160P": "Bluray-2160p Remux", "BLURAY_2160P": "Bluray-2160p", "WEBDL_2160P": "WEBDL-2160p",
        "WEBRIP_2160P": "WEBRip-2160p", "HDTV_2160P": "HDTV-2160p", "REMUX_1080P": "Bluray-1080p Remux",
        "BLURAY_1080P": "Bluray-1080p", "WEBDL_1080P": "WEBDL-1080p", "WEBRIP_1080P": "WEBRip-1080p",
        "RAWHD": "Raw-HD", "HDTV_1080P": "HDTV-1080p", "BLURAY_720P": "Bluray-720p", "WEBDL_720P": "WEBDL-720p",
        "WEBRIP_720P": "WEBRip-720p", "HDTV_720P": "HDTV-720p", "BLURAY_576P": "Bluray-576p",
        "BLURAY_480P": "Bluray-480p", "DVD": "DVD", "DVDR": "DVD-R", "WEBDL_480P": "WEBDL-480p",
        "WEBRIP_480P": "WEBRip-480p", "SDTV": "SDTV", "BRDISK": "BR-DISK", "DVDSCR": "DVDSCR",
        "REGIONAL": "REGIONAL", "TELECINE": "TELECINE", "TELESYNC": "TELESYNC", "CAM": "CAM",
        "WORKPRINT": "WORKPRINT", "UNKNOWN": "Unknown",
    ]

    static func quality(_ raw: String) -> String { qualityLabels[raw] ?? raw }

    static func protocolLabel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw.uppercased() {
        case "USENET": return "Usenet"
        case "TORRENT": return "Torrent"
        default: return raw.capitalized
        }
    }

    static func plural(_ n: Int, _ word: String, _ pluralWord: String? = nil) -> String {
        "\(n) \(n == 1 ? word : (pluralWord ?? word + "s"))"
    }

    static func taskLabel(_ name: String) -> String {
        let labels = ["rss_sync": "RSS Sync", "import_poll": "Import & Download Poll", "metadata_refresh": "Metadata Refresh",
                      "metadata-refresh": "Full catalog sync", "metadata-refresh-active": "Active series sync",
                      "air-times": "Air-times", "anime-ids": "Anime IDs"]
        if let label = labels[name] { return label }
        return name.replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
            .split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

// MARK: Paged feed (the web's useInfiniteList)

@MainActor
@Observable
final class ActFeed<Item: Identifiable> {
    private(set) var items: [Item] = []
    private(set) var total = 0
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var loadingMore = false
    private(set) var pages = 1
    private var generation = 0
    let pageSize: Int
    @ObservationIgnored var fetch: (_ page: Int, _ pageSize: Int) async throws -> ([Item], Int)

    init(pageSize: Int = 50, fetch: @escaping (_ page: Int, _ pageSize: Int) async throws -> ([Item], Int)) {
        self.pageSize = pageSize
        self.fetch = fetch
    }

    var hasMore: Bool { items.count < total }

    /// Loads the first page again (a new search or a pull to refresh).
    func reload(resetting: Bool = false) async {
        generation += 1
        let gen = generation
        if resetting { loaded = false; items = []; total = 0 }
        do {
            let (page, total) = try await fetch(1, pageSize)
            guard gen == generation else { return }
            items = page
            self.total = total
            pages = 1
            error = nil
        } catch is CancellationError {
            return
        } catch {
            guard gen == generation else { return }
            if (error as? URLError)?.code == .cancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    /// Re-reads every loaded page in one request (live polling).
    func refreshLoaded() async {
        let size = min(pageSize * pages, 500)
        let gen = generation
        guard let (page, total) = try? await fetch(1, size), gen == generation else { return }
        items = page
        self.total = total
        error = nil
        loaded = true
    }

    func loadMore() async {
        guard hasMore, !loadingMore, loaded else { return }
        loadingMore = true
        defer { loadingMore = false }
        let gen = generation
        do {
            let (page, total) = try await fetch(pages + 1, pageSize)
            guard gen == generation else { return }
            let seen = Set(items.map { AnyHashable($0.id) })
            items += page.filter { !seen.contains(AnyHashable($0.id)) }
            self.total = total
            pages += 1
        } catch {}
    }

    /// Drops rows locally (optimistic remove).
    func remove(where predicate: (Item) -> Bool) {
        let before = items.count
        items.removeAll(where: predicate)
        total = max(0, total - (before - items.count))
    }
}

// MARK: Motion (components/motion/Reveal + the queue/tasks @keyframes)

private struct ActReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the OS asks for reduced motion OR the server's `animations_enabled`
    /// setting is off — the web's `useReduceMotion()`.
    var actReduceMotion: Bool {
        get { self[ActReduceMotionKey.self] }
        set { self[ActReduceMotionKey.self] = newValue }
    }
}

enum ActMotion {
    /// The web's `REVEAL_EASE` cubic-bezier(.52,.01,.16,1).
    static func reveal(_ duration: Double = 0.5) -> Animation { .timingCurve(0.52, 0.01, 0.16, 1, duration: duration) }
    /// Progress-fill width transition: cubic-bezier(.3,.7,.3,1) 0.5s.
    static let fill = Animation.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.5)
    /// Row insert/remove.
    static let rows = Animation.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.35)

    /// CSS `ease-in-out` on a 0...1 phase.
    static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
}

/// Loops a 0...1 phase every `duration` seconds (CSS `animation: … infinite`).
/// Stops (phase 0 / static) under reduced motion.
struct ActLoop<Content: View>: View {
    let duration: Double
    @Environment(\.actReduceMotion) private var reduce
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        if reduce {
            content(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                content(t.truncatingRemainder(dividingBy: duration) / duration)
            }
        }
    }
}

/// `queue-sweep` / `activity-sweep`: a light band crossing a progress fill, 1.35s ease-in-out.
struct ActShimmer: View {
    var duration = 1.35
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        if !reduce {
            GeometryReader { geo in
                ActLoop(duration: duration) { phase in
                    let x = -1 + 2 * ActMotion.easeInOut(phase)
                    LinearGradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width)
                        .offset(x: geo.size.width * x)
                }
            }
            .clipped()
            .allowsHitTesting(false)
        }
    }
}

/// `queue-indet`: an indeterminate 36%-wide band sliding from -36% to 100%.
struct ActIndeterminateBar: View {
    var color: Color = Theme.indigo
    var height: CGFloat = 5
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.txt.opacity(0.09))
                if reduce {
                    Capsule().fill(color.opacity(0.6)).frame(width: geo.size.width * 0.36)
                } else {
                    ActLoop(duration: 1.35) { phase in
                        let left = -0.36 + 1.36 * ActMotion.easeInOut(phase)
                        Capsule()
                            .fill(LinearGradient(colors: [color.opacity(0), color, color.opacity(0)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * 0.36)
                            .offset(x: geo.size.width * left)
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

/// `queue-pulse-dot` / `tasks-livepulse` / `queue-hold-breathe`: a dot with an
/// expanding ring that fades out.
struct ActPulseDot: View {
    let color: Color
    var size: CGFloat = 7
    var spread: CGFloat = 7
    var duration = 1.8

    var body: some View {
        ActLoop(duration: duration) { phase in
            let p = min(phase / 0.7, 1)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.55 * (1 - p)))
                        .frame(width: size + 2 * spread * p, height: size + 2 * spread * p))
        }
        .frame(width: size, height: size)
    }
}

/// `processspin` / `task-spin`: a continuous rotation (static under reduced motion).
struct ActSpin: ViewModifier {
    let active: Bool
    var duration = 0.8

    func body(content: Content) -> some View {
        if active {
            ActLoop(duration: duration) { phase in
                content.rotationEffect(.degrees(360 * phase))
            }
        } else {
            content
        }
    }
}

/// `Reveal` / `RevealItem`: fade + 16pt rise on first appearance, staggered.
struct ActReveal: ViewModifier {
    var index = 0
    var stagger = 0.04
    @Environment(\.actReduceMotion) private var reduce
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(reduce || shown ? 1 : 0)
            .offset(y: reduce || shown ? 0 : 16)
            .onAppear {
                guard !reduce, !shown else { return }
                withAnimation(ActMotion.reveal().delay(Double(min(index, 12)) * stagger)) { shown = true }
            }
    }
}

extension View {
    func actReveal(_ index: Int = 0, stagger: Double = 0.04) -> some View { modifier(ActReveal(index: index, stagger: stagger)) }
    func actSpin(_ active: Bool, duration: Double = 0.8) -> some View { modifier(ActSpin(active: active, duration: duration)) }

    /// List insert/remove: fade + slight slide, no motion under reduce.
    func actRowTransition(_ reduce: Bool) -> some View {
        transition(reduce ? .identity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 12)),
                                                     removal: .opacity.combined(with: .scale(scale: 0.97))))
    }
}

/// A gradient progress fill with the width transition and the shimmer sweep.
struct ActProgressBar: View {
    let fraction: Double
    var height: CGFloat = 5
    var fill: AnyShapeStyle = AnyShapeStyle(LinearGradient(colors: [Theme.grab.opacity(0.7), Theme.indigo, Theme.grab], startPoint: .leading, endPoint: .trailing))
    var shimmer = true
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.txt.opacity(0.09))
                Capsule()
                    .fill(fill)
                    .overlay { if shimmer { ActShimmer() } }
                    .clipShape(Capsule())
                    .frame(width: max(0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(reduce ? nil : ActMotion.fill, value: fraction)
    }
}

// MARK: Shared row actions (use-blocklist-action / use-regrab-action / copy)

@MainActor
enum ActActions {
    /// `POST /api/v1/blocklist` with the web's toasts. `undo` offers an Undo that
    /// lifts the new entry again.
    static func blocklist(_ client: APIClient?, _ toaster: ActToaster, _ body: BlocklistCreate,
                          offerUndo: Bool = false, done: @escaping () -> Void = {}) async {
        guard let client else { return }
        do {
            let result = try await client.blocklistRelease(body)
            let searching = result.searchDispatched == true
            let message: String
            if result.fileDeleted == true {
                message = searching ? "Blocklisted, deleted the file, and searching for a replacement" : "Blocklisted and deleted the file"
            } else if result.created {
                message = searching ? "Blocklisted — searching for a replacement" : "Release blocklisted"
            } else {
                message = searching ? "Already blocklisted — searching for a replacement" : "Already blocklisted"
            }
            let tone: ActToaster.Tone = result.created || searching ? .success : .warning
            if offerUndo, result.created, let id = result.entry?.id {
                toaster.show(message, tone: tone, undo: {
                    Task {
                        do {
                            try await client.deleteBlocklistEntry(id: id)
                            toaster.show("Blocklist cleared", tone: .success)
                            done()
                        } catch { toaster.error(error) }
                    }
                })
            } else {
                toaster.show(message, tone: tone)
            }
            done()
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            toaster.show(error.serverDetail ?? "Couldn't blocklist this release — try again", tone: .warning)
        } catch {
            toaster.show("Couldn't blocklist this release — try again", tone: .error)
        }
    }

    static func search(_ client: APIClient?, _ toaster: ActToaster, itemId: Int, editionId: Int? = nil,
                       episodeId: Int? = nil, message: String) async {
        guard let client else { return }
        do {
            try await client.runSearch(itemId: itemId, editionId: editionId, episodeId: episodeId)
            toaster.show(message)
        } catch {
            toaster.error(error)
        }
    }

    static func copy(_ text: String?, _ toaster: ActToaster) {
        guard let text, !text.isEmpty else { return }
        UIPasteboard.general.string = text
        toaster.show("Release name copied")
    }
}
