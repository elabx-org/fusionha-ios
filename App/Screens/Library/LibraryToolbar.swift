import SwiftUI
import FusionhaKit

/// The Library control row (redesign): one line of glass. Tier switch,
/// kinds menu with counts, then Filters (with its badge), grid / list and
/// select. Everything the web's kinds card and toolbar did, minus the chrome.
struct LibraryToolbar: View {
    let derived: LibraryDerived
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Binding var kind: String
    @Binding var tier: LibraryTier
    @Binding var density: String
    /// Filters set inside the sheet (recency, group, a non-title sort).
    let filterBadge: Int
    let openFilters: () -> Void

    private var active: LibraryKind? { LibraryKind(rawValue: kind) }
    private func titles(_ k: LibraryKind) -> Int { derived.kindTitles[k] ?? 0 }

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)
                    .fixedSize()
                kindsMenu
                Spacer(minLength: 0)
                filters
                GlassIconButton(systemName: density == "grid" ? "square.grid.2x2" : "list.bullet",
                                label: density == "grid" ? "Switch to list" : "Switch to grid") {
                    withAnimation(motion ? Motion.indicator : nil) { density = density == "grid" ? "compact" : "grid" }
                }
                .sensoryFeedback(.selection, trigger: density)
                GlassIconButton(systemName: model.selectMode ? "checkmark.circle.fill" : "checkmark.circle",
                                label: model.selectMode ? "Exit select mode" : "Select titles",
                                on: model.selectMode) {
                    if model.selectMode { model.exitSelectMode() } else { model.selectMode = true }
                }
            }
        }
    }

    // MARK: Kinds

    private var kindsMenu: some View {
        Menu {
            Picker("Kind", selection: kindBinding) {
                Text("All kinds").tag("all")
                ForEach(shownKinds, id: \.self) { k in
                    Label("\(k.plural) · \(titles(k))", systemImage: icon(k)).tag(k.rawValue)
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                GlassMenuLabel(title: active?.plural ?? "All kinds", on: active != nil)
                GlassMenuLabel(title: active?.plural ?? "Kinds", on: active != nil)
            }
        }
        .accessibilityLabel("Kind: \(active?.plural ?? "All kinds")")
    }

    private var kindBinding: Binding<String> {
        Binding(get: { kind }, set: { next in withAnimation(motion ? .snappy : nil) { kind = next } })
    }

    /// Movies, Series and Anime always; Animation only when there is some.
    private var shownKinds: [LibraryKind] {
        var kinds: [LibraryKind] = [.movie, .series, .anime]
        if titles(.animation) > 0 || active == .animation { kinds.append(.animation) }
        return kinds
    }

    private func icon(_ k: LibraryKind) -> String {
        switch k {
        case .movie: return "film"
        case .series, .anime: return "tv"
        case .animation: return "paintbrush.pointed"
        }
    }

    // MARK: Filters

    private var filters: some View {
        GlassIconButton(systemName: "line.3.horizontal.decrease", label: "Filters",
                        on: filterBadge > 0, action: openFilters)
            .overlay(alignment: .topTrailing) {
                if filterBadge > 0 {
                    Text("\(filterBadge)")
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(Theme.onAccent)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Theme.primary, in: Capsule())
                        .offset(x: 4, y: -4)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityValue(filterBadge > 0 ? "\(filterBadge) active" : "")
    }
}
