import SwiftUI
import FusionhaKit

// W1 modules whose rows run through a lazy stack: each row draws its own
// slice of the card (`ModuleListSegment`), so a long feed (History's
// stories, the blocklist, Wanted) keeps the stack lazy and still reads as
// one frosted card, rows split by hairlines.

extension View {
    /// Row `index` of a `count`-row W1 module in a lazy stack. `selected`
    /// rings the row in the accent (the open Duo's chosen item).
    func v2ModuleRow(_ index: Int, of count: Int, selected: Bool = false) -> some View {
        modifier(V2ModuleRowModifier(position: ModuleListSegment.Position(index: index, count: count),
                                     selected: selected))
    }

    /// The gap a block leaves under itself in a scope's lazy stack.
    func v2ScopeBlock(_ spacing: CGFloat = 12) -> some View {
        padding(.bottom, spacing)
    }
}

private struct V2ModuleRowModifier: ViewModifier {
    let position: ModuleListSegment.Position
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ModuleMetrics.inset)
            .padding(.vertical, ModuleMetrics.rowPadding)
            .padding(.top, position.roundsTop ? 2 : 0)
            .padding(.bottom, position.roundsBottom ? 2 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { ModuleListSegment(position: position, gutter: 0) }
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.primary, lineWidth: 2)
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, position.roundsBottom ? 12 : 0)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The caption inside a module's first row (cards-w.js `.ac-h`).
struct V2ModuleCaption: View {
    let text: String
    var systemImage: String?
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold)).frame(width: 14, height: 14)
            }
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
        .padding(.bottom, 10)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small poster thumb (clean art, no text on it).
struct V2ScopeThumb: View {
    let url: String?
    var width: CGFloat = 40

    var body: some View {
        let size = CGSize(width: width, height: (width * 1.5).rounded())
        PosterImage(url: TMDBImage.resized(url, to: "w185"), size: size)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: width >= 50 ? 10 : 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A round glass icon button (mock `.lg-sb` / `.lg-ra span`).
struct V2RoundIconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 36
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: systemImage).font(.system(size: size * 0.42, weight: .semibold))
                }
            }
            .foregroundStyle(Theme.txt)
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(busy)
        .accessibilityLabel(label)
    }
}

/// A short glass capsule button with an icon and a label (mock `.ac-b ter`).
struct V2CapsuleButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if busy { ProgressView().controlSize(.mini) } else { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(prominent ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(prominent ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .disabled(busy)
    }
}
