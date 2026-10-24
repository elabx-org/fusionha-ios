import SwiftUI
import FusionhaKit

/// The Library's kind control in a narrow list column (option A, the flat
/// Duo's third-wide list beside an open title): one native menu, "All ·
/// 3,785", with every kind and its count inside it. Same kinds, order and
/// words as `LibraryKindSegment`; tapping the chosen kind again isn't needed
/// here, All is in the menu.
struct LibraryKindMenu: View {
    let derived: LibraryDerived
    @Binding var kind: String
    @Environment(\.motionEnabled) private var motion

    private var active: LibraryKind? { LibraryKind(rawValue: kind) }
    private var kinds: [LibraryKind] { KindControl.kinds(titles: derived.kindTitles, active: active) }
    private var allCount: Int { derived.kindTitles.values.reduce(0, +) }
    private func titles(_ k: LibraryKind) -> Int { derived.kindTitles[k] ?? 0 }
    private var label: String { active?.plural ?? "All" }
    private var count: Int { active.map { titles($0) } ?? allCount }

    private var selection: Binding<String> {
        Binding(get: { active?.rawValue ?? "all" },
                set: { next in withAnimation(motion ? Motion.indicator : nil) { kind = next } })
    }

    var body: some View {
        Menu {
            Picker("Kind", selection: selection) {
                Text("All · \(allCount.formatted())").tag("all")
                ForEach(kinds, id: \.self) { k in
                    Text("\(k.plural) · \(titles(k).formatted())").tag(k.rawValue)
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let active { Circle().fill(Theme.kind(active)).frame(width: 7, height: 7) }
                Text(label).foregroundStyle(Theme.txt)
                Text("· \(count.formatted())").fontWeight(.medium).foregroundStyle(Theme.mut)
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mut)
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: kind)
        .accessibilityLabel("Kind")
        .accessibilityValue("\(label), \(count) \(count == 1 ? "title" : "titles")")
    }
}
