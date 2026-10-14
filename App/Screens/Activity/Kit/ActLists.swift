import SwiftUI
import FusionhaKit

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
                    ProgressView().controlSize(.small).tint(Theme.indigo)
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
                // Infinite scroll like the web's IntersectionObserver: only when the
                // footer is actually on screen, never just because it was built.
                .onScrollVisibilityChange(threshold: 0.05) { visible in if visible { loadMore() } }
            } else if total > 0 {
                HStack(spacing: 8) {
                    hairline
                    (Text("You’ve reached the end").bold().foregroundColor(Theme.mut)
                     + Text(" · showing all ")
                     + Text("\(total)").font(.system(size: 12.5, design: .monospaced)).foregroundColor(Theme.i2)
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
        LinearGradient(colors: [Theme.i1.opacity(0), Theme.i2.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34, height: 1)
    }
}

// MARK: GroupCard

struct ActGroupCard<PosterV: View, TitleV: View, TrailingV: View, BodyV: View>: View {
    var wash: Color?
    var base: Color = Theme.panel
    var hasTrailing = true
    /// Told each time the card opens or closes (to remember it).
    var onToggle: ((Bool) -> Void)? = nil
    @State private var open: Bool
    @Environment(\.actReduceMotion) private var reduceMotion
    private let poster: PosterV
    private let title: TitleV
    private let trailing: TrailingV
    private let content: BodyV

    init(wash: Color? = nil, base: Color = Theme.panel, defaultOpen: Bool = true, hasTrailing: Bool = true,
         onToggle: ((Bool) -> Void)? = nil,
         @ViewBuilder poster: () -> PosterV, @ViewBuilder title: () -> TitleV,
         @ViewBuilder trailing: () -> TrailingV, @ViewBuilder content: () -> BodyV) {
        self.wash = wash
        self.base = base
        self.hasTrailing = hasTrailing
        self.onToggle = onToggle
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
                        onToggle?(open)
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
                    .accessibilityValue(open ? "Expanded" : "Collapsed")
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
