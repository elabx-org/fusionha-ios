import SwiftUI

/// The rail's highlighted letter, written by the Library's scroll-spy. Its own
/// object so scrolling re-renders the rail only, never the page.
@MainActor
@Observable
final class AlphaRailState {
    var active: String?

    func set(_ letter: String?) {
        if active != letter { active = letter }
    }
}

/// The A–Z index past 720 (AlphabetRail.tsx desktop rail, ruling L17): a 34pt
/// column at the content's trailing edge, every letter of '#'…Z spread over
/// its height, a hairline on its leading side. Letters with titles jump to
/// their header; the rest are dimmed and disabled; the letter at the top of
/// the grid is highlighted. Dragging along it scrubs, as on the phone's thumb.
struct LibraryAlphaRail: View {
    static let width: CGFloat = 34

    let present: Set<String>
    let state: AlphaRailState
    let jump: (String) -> Void
    @State private var lastScrub: String?

    private let letters = LibraryAlphaIndex.alphabet

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 1) {
                ForEach(letters, id: \.self) { letter in
                    button(letter)
                }
            }
            .padding(.vertical, 8)
            .frame(width: Self.width, height: geo.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(scrub(height: geo.size.height))
        }
        .frame(width: Self.width)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
        .sensoryFeedback(.selection, trigger: lastScrub) { _, new in new != nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Jump to letter")
    }

    private func button(_ letter: String) -> some View {
        let has = present.contains(letter)
        let on = state.active == letter
        return Button { jump(letter) } label: {
            Text(letter)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(on ? Theme.i2 : has ? Theme.mut : Theme.dim)
                .frame(width: 24)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!has)
        .opacity(has ? 1 : 0.35)
        .accessibilityLabel(has ? "Jump to \(letter)" : "No titles starting with \(letter)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Finger position → the nearest letter that has titles at or after it.
    private func scrub(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let track = max(height - 16, 1)
                let slot = Int(((value.location.y - 8) / track * CGFloat(letters.count)).rounded(.down))
                let index = min(max(slot, 0), letters.count - 1)
                guard let letter = letters[index...].first(where: present.contains) ?? letters.last(where: present.contains),
                      letter != lastScrub else { return }
                lastScrub = letter
                jump(letter)
            }
            .onEnded { _ in lastScrub = nil }
    }
}
