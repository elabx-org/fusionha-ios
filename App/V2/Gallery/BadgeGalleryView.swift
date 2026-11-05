import SwiftUI

/// v2's Badge gallery (plan S2): every badge, ticket pair and rail state on
/// every palette (Daylight included), at the default text size and at a
/// large Dynamic Type size, plus the joined ⇄ apart animation. Each palette
/// card draws in that palette's own tokens, whichever palette is active.
struct BadgeGalleryView: View {
    enum TextSize: String, CaseIterable, Identifiable {
        case both = "Both", standard = "Default", large = "Large"
        var id: String { rawValue }
    }

    @State private var textSize: TextSize = .both
    @State private var palettes: Set<AppPalette> = Set(AppPalette.allCases)

    /// Daylight right after Aurora: the light palette is the one most likely to break.
    private static let order: [AppPalette] = [.aurora, .daylight, .monochrome, .noir, .graphite, .oled, .frost, .eclipse]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                controls
                BadgeGalleryAnimationDemo()
                ForEach(Self.order.filter { palettes.contains($0) }) { palette in
                    if textSize != .large {
                        BadgeGalleryPaletteCard(palette: palette, sizeLabel: "Default")
                            .dynamicTypeSize(.large)
                    }
                    if textSize != .standard {
                        BadgeGalleryPaletteCard(palette: palette, sizeLabel: "Large text")
                            .dynamicTypeSize(.accessibility2)
                    }
                }
            }
            .padding(.horizontal, Theme.pageGutter)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Text size", selection: $textSize) {
                ForEach(TextSize.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Menu {
                Button("All palettes") { palettes = Set(AppPalette.allCases) }
                ForEach(Self.order) { p in
                    Button(p.name) { palettes = [p] }
                }
            } label: {
                Label(palettes.count == AppPalette.allCases.count ? "All palettes" : palettes.first?.name ?? "Palettes",
                      systemImage: "paintpalette")
            }
            .buttonStyle(.glass)
            Text("Filled = on disk · outline = missing · ring = downloading · orange \u{201C}!\u{201D} = held. HD and 4K plug together only when they say the same thing.")
                .font(.footnote)
                .foregroundStyle(Theme.mut)
        }
    }
}

/// Tap to step a pair through joined and apart states (`.snappy`, or no
/// motion with Reduce Motion on).
private struct BadgeGalleryAnimationDemo: View {
    @State private var step = 0

    var body: some View {
        let pair = BadgeGallerySamples.cycle[step % BadgeGallerySamples.cycle.count]
        Button {
            step += 1
        } label: {
            HStack(spacing: 12) {
                EditionTicketPair(hd: pair.0, uhd: pair.1)
                Spacer(minLength: 8)
                Text("Tap to change")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.mut)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Steps the badges through joined and apart states")
    }
}
