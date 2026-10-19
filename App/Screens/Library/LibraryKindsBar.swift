import SwiftUI
import FusionhaKit

/// The web's kind selector on phones (LibraryPulse.tsx `selrow`): the selected
/// kind's badge, the proportional Movies / Series / Anime make-up bar, then a
/// scrolling row of chips (All, each kind with its count, Animation when there
/// is some). Tapping the active kind again goes back to All.
struct LibraryKindsBar: View {
    let derived: LibraryDerived
    @Binding var kind: String
    @Environment(\.motionEnabled) private var motion

    private static let barKinds: [LibraryKind] = [.movie, .series, .anime]
    private var active: LibraryKind? { LibraryKind(rawValue: kind) }
    private func titles(_ k: LibraryKind) -> Int { derived.kindTitles[k] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            badge
            compositionBar
            chips
        }
    }

    private func select(_ next: LibraryKind?) {
        let raw = next?.rawValue ?? "all"
        withAnimation(motion ? .snappy : nil) { kind = (raw == kind && next != nil) ? "all" : raw }
    }

    // MARK: Badge

    private var accent: Color { active.map { Theme.kind($0) } ?? Theme.i2 }

    private var badge: some View {
        let present = LibraryKind.allCases.filter { titles($0) > 0 }.count
        let versions = active.map { derived.kindEditions[$0] ?? 0 } ?? 0
        return HStack(spacing: 9) {
            Image(systemName: icon(active))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 1) {
                Text(active?.plural ?? "All kinds")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Text(LibraryPhoneCopy.kindSubtitle(allKinds: active == nil, kindsPresent: present, versions: versions))
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.mut)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Composition bar

    private var compositionBar: some View {
        let total = Self.barKinds.reduce(0) { $0 + titles($1) }
        return GeometryReader { geo in
            let gaps = CGFloat(Self.barKinds.count - 1) * 2
            let free = max(geo.size.width - gaps - CGFloat(Self.barKinds.count) * 5, 0)
            HStack(spacing: 2) {
                ForEach(Self.barKinds, id: \.self) { k in
                    let share = total > 0 ? CGFloat(titles(k)) / CGFloat(total) : 1 / CGFloat(Self.barKinds.count)
                    let on = active == k
                    Button { select(k) } label: {
                        Rectangle()
                            .fill(Theme.kind(k))
                            .opacity(active == nil || on ? 1 : 0.55)
                            .frame(width: 5 + free * share)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(k.plural) · \(titles(k)) \(titles(k) == 1 ? "title" : "titles")")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .frame(height: 12)
        .background(Theme.txt.opacity(0.06))
        .clipShape(Capsule())
        .animation(motion ? .smooth(duration: 0.6) : nil, value: derived.kindTitles)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library make-up by kind")
    }

    // MARK: Chips

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 7) {
                HStack(spacing: 7) {
                    chip(nil, label: "All", count: nil)
                    ForEach(Self.barKinds, id: \.self) { k in
                        chip(k, label: k.plural, count: titles(k))
                    }
                    if titles(.animation) > 0 || active == .animation {
                        chip(.animation, label: "Animation", count: titles(.animation))
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ k: LibraryKind?, label: String, count: Int?) -> some View {
        let on = active == k
        let tone = k.map { Theme.kind($0) } ?? Theme.i1
        return Button { select(k) } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(tone).frame(width: 8, height: 8)
                if let count {
                    Text("\(count)").font(.system(size: 12.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                        .contentTransition(.numericText())
                }
                Text(label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(on ? Theme.txt : Theme.mut)
            }
            .padding(.leading, 10)
            .padding(.trailing, 11)
            .frame(height: 30)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(tone.opacity(0.22)).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }

    private func icon(_ k: LibraryKind?) -> String {
        switch k {
        case nil: return "square.stack"
        case .movie: return "film"
        case .series: return "tv"
        case .anime: return "sparkles.tv"
        case .animation: return "star"
        }
    }
}
