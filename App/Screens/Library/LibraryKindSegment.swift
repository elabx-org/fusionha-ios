import SwiftUI
import FusionhaKit

/// The Library's kind control (owner-approved layout A, mock `.kseg`): one
/// segmented control "All 14 · Movies 5 · Series 4 · Anime 5", a coloured dot
/// per kind and its count in the dim colour, with the proportional make-up bar
/// along its bottom edge under the kind segments. Animation joins only when
/// the library has some. It replaced the four-row kinds block.
struct LibraryKindSegment: View {
    let derived: LibraryDerived
    @Binding var kind: String
    @Environment(\.motionEnabled) private var motion
    @Namespace private var indicator

    private static let barKinds: [LibraryKind] = [.movie, .series, .anime]
    private var active: LibraryKind? { LibraryKind(rawValue: kind) }
    private func titles(_ k: LibraryKind) -> Int { derived.kindTitles[k] ?? 0 }

    private var kinds: [LibraryKind] {
        Self.barKinds + (titles(.animation) > 0 || active == .animation ? [.animation] : [])
    }

    private var allCount: Int { derived.kindTitles.values.reduce(0, +) }

    var body: some View {
        HStack(spacing: 0) {
            segment(nil, label: "All", count: allCount)
            ForEach(kinds, id: \.self) { k in
                segment(k, label: k.plural, count: titles(k))
            }
        }
        .padding([.horizontal, .top], 3)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) { mixBar }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sensoryFeedback(.selection, trigger: kind)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kind")
    }

    private func select(_ next: LibraryKind?) {
        let raw = next?.rawValue ?? "all"
        withAnimation(motion ? Motion.indicator : nil) { kind = (raw == kind && next != nil) ? "all" : raw }
    }

    private func segment(_ k: LibraryKind?, label: String, count: Int) -> some View {
        let on = active == k
        return Button { select(k) } label: {
            HStack(spacing: 5) {
                if let k { Circle().fill(Theme.kind(k)).frame(width: 7, height: 7) }
                Text(label).foregroundStyle(on ? Theme.txt : Theme.mut)
                Text("\(count)")
                    .fontWeight(.medium)
                    .foregroundStyle(on ? Theme.mut : Theme.dim)
                    .contentTransition(.numericText())
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.isLight ? Theme.panel : Theme.txt.opacity(0.12))
                        .shadow(color: .black.opacity(Theme.isLight ? 0.08 : 0.25), radius: 2, y: 1)
                        .matchedGeometryEffect(id: "kind", in: indicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count) \(count == 1 ? "title" : "titles")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The make-up bar under the kind segments (`.mix`: from the second
    /// segment to 6pt short of the edge, 3pt tall, 2pt gaps).
    private var mixBar: some View {
        GeometryReader { geo in
            let segments = CGFloat(kinds.count + 1)
            let lead = 3 + (geo.size.width - 6) / segments
            let width = max(geo.size.width - lead - 6, 0)
            let shares = KindMix.shares(Self.barKinds.map(titles))
            let free = max(width - CGFloat(shares.count - 1) * 2, 0)
            HStack(spacing: 2) {
                ForEach(Array(Self.barKinds.enumerated()), id: \.offset) { i, k in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.kind(k))
                        .opacity(active == nil || active == k ? 1 : 0.45)
                        .frame(width: free * CGFloat(shares[i]))
                }
            }
            .frame(height: 3)
            .offset(x: lead, y: geo.size.height - 7)
        }
        .animation(motion ? .smooth(duration: 0.6) : nil, value: derived.kindTitles)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
