import SwiftUI
import FusionhaKit

/// The Library's kind control (owner-approved layout A, mock `.kseg`): one
/// segmented control "All 3,785 · Movies 2,629 · Series 734 · Anime 37 ·
/// Animation 385", a coloured dot per kind, with the proportional make-up bar
/// along its bottom edge under the kind segments. Animation joins only when
/// the library has some (`KindControl.kinds`).
///
/// It never truncates a label: `ViewThatFits` takes the first form that fits
/// (`KindControl.Fit`): every segment with its count; the segments without
/// counts (the counts move to the summary line, `countsInSummary`); then a
/// sideways row of capsules with counts and no bar. Segments are as wide as
/// their words plus an even share of the spare room, and the bar is laid out
/// from their real frames, so it stays under them.
struct LibraryKindSegment: View {
    let derived: LibraryDerived
    @Binding var kind: String
    /// The labels-only form is showing: the header's summary line carries the counts.
    @Binding var countsInSummary: Bool
    @Environment(\.motionEnabled) private var motion
    @Namespace private var indicator

    private var active: LibraryKind? { LibraryKind(rawValue: kind) }
    private func titles(_ k: LibraryKind) -> Int { derived.kindTitles[k] ?? 0 }
    private var kinds: [LibraryKind] { KindControl.kinds(titles: derived.kindTitles, active: active) }
    private var allCount: Int { derived.kindTitles.values.reduce(0, +) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            segmented(.counts)
            segmented(.labels)
                .onAppear { countsInSummary = true }
                .onDisappear { countsInSummary = false }
            capsules
        }
        .sensoryFeedback(.selection, trigger: kind)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kind")
    }

    private func select(_ next: LibraryKind?) {
        let raw = next?.rawValue ?? "all"
        withAnimation(motion ? Motion.indicator : nil) { kind = (raw == kind && next != nil) ? "all" : raw }
    }

    // MARK: Segmented forms

    private func segmented(_ fit: KindControl.Fit) -> some View {
        KindSegmentsLayout {
            segment(nil, label: "All", count: allCount, fit: fit)
            ForEach(kinds, id: \.self) { k in
                segment(k, label: k.plural, count: titles(k), fit: fit)
            }
            mixBar.layoutValue(key: KindSegmentsLayout.IsBar.self, value: true)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func segment(_ k: LibraryKind?, label: String, count: Int, fit: KindControl.Fit) -> some View {
        let on = active == k
        return Button { select(k) } label: {
            HStack(spacing: 5) {
                if let k { Circle().fill(Theme.kind(k)).frame(width: 7, height: 7) }
                Text(label).foregroundStyle(on ? Theme.txt : Theme.mut)
                if fit == .counts {
                    Text("\(count)")
                        .fontWeight(.medium)
                        .foregroundStyle(on ? Theme.mut : Theme.dim)
                        .contentTransition(.numericText())
                }
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.isLight ? Theme.panel : Theme.txt.opacity(0.12))
                        .shadow(color: .black.opacity(Theme.isLight ? 0.08 : 0.25), radius: 2, y: 1)
                        .matchedGeometryEffect(id: "kind-\(fit)", in: indicator)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count) \(count == 1 ? "title" : "titles")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// The make-up bar: every shown kind's share of the titles, laid out by
    /// `KindSegmentsLayout` under the kind segments (`KindControl.barSpan`).
    private var mixBar: some View {
        GeometryReader { geo in
            let pieces = KindControl.barPieces(width: geo.size.width, counts: kinds.map(titles), gap: 2)
            HStack(spacing: 2) {
                ForEach(Array(kinds.enumerated()), id: \.element) { i, k in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.kind(k))
                        .opacity(active == nil || active == k ? 1 : 0.45)
                        .frame(width: pieces[i])
                }
            }
        }
        .frame(height: 3)
        .animation(motion ? .smooth(duration: 0.6) : nil, value: derived.kindTitles)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Capsule row (narrowest)

    private var capsules: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 7) {
                HStack(spacing: 7) {
                    capsule(nil, label: "All", count: allCount)
                    ForEach(kinds, id: \.self) { k in capsule(k, label: k.plural, count: titles(k)) }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func capsule(_ k: LibraryKind?, label: String, count: Int) -> some View {
        let on = active == k
        let tone = k.map { Theme.kind($0) } ?? Theme.i1
        return Button { select(k) } label: {
            HStack(spacing: 5) {
                if let k { Circle().fill(Theme.kind(k)).frame(width: 7, height: 7) }
                Text(label).foregroundStyle(on ? Theme.txt : Theme.mut)
                Text("\(count)").fontWeight(.medium).foregroundStyle(on ? Theme.mut : Theme.dim)
            }
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(tone.opacity(0.22)).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityLabel("\(label), \(count) \(count == 1 ? "title" : "titles")")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The segmented forms' row: each segment its ideal width plus an even share
/// of the spare room (never less than its words), 3 pt inset, 34 tall, and
/// the make-up bar (`IsBar`) 3 pt under the kind segments, from the first
/// kind segment to the last (`KindControl.barSpan`), so it can't drift off them.
struct KindSegmentsLayout: Layout {
    struct IsBar: LayoutValueKey {
        static let defaultValue = false
    }

    private static let inset: CGFloat = 3
    private static let segmentHeight: CGFloat = 34
    private static let barGap: CGFloat = 3
    private static let height: CGFloat = inset + segmentHeight + 9

    private func split(_ subviews: Subviews) -> (segments: [LayoutSubview], bar: LayoutSubview?) {
        (subviews.filter { !$0[IsBar.self] }, subviews.first { $0[IsBar.self] })
    }

    private func ideals(_ segments: [LayoutSubview]) -> [CGFloat] {
        segments.map { $0.sizeThatFits(.unspecified).width }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = ideals(split(subviews).segments).reduce(0, +) + Self.inset * 2
        return CGSize(width: max(proposal.width ?? ideal, ideal), height: Self.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (segments, bar) = split(subviews)
        let widths = ideals(segments)
        let spare = max(bounds.width - Self.inset * 2 - widths.reduce(0, +), 0) / CGFloat(max(segments.count, 1))
        var x = bounds.minX + Self.inset
        var frames: [(x: Double, width: Double)] = []
        for (segment, ideal) in zip(segments, widths) {
            let width = ideal + spare
            segment.place(at: CGPoint(x: x, y: bounds.minY + Self.inset),
                          proposal: ProposedViewSize(width: width, height: Self.segmentHeight))
            frames.append((Double(x), Double(width)))
            x += width
        }
        guard let bar else { return }
        // All is the first segment; the bar runs under the kinds after it.
        if let span = KindControl.barSpan(segments: Array(frames.dropFirst()), inset: 3) {
            bar.place(at: CGPoint(x: span.x, y: bounds.minY + Self.inset + Self.segmentHeight + Self.barGap),
                      proposal: ProposedViewSize(width: span.width, height: 3))
        } else {
            bar.place(at: bounds.origin, proposal: .zero)
        }
    }
}
