import SwiftUI
import FusionhaKit

/// Home's one door to every title (Home mock `.allc`): a small fanned stack
/// of posters, "All titles", "3,407 · A–Z grid with filters and the
/// scrubber" and a chevron. A W1 module (`ModuleSurface`), not glass.
struct V2AllTitlesCard: View {
    let data: V2HomeData
    let open: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                stack
                VStack(alignment: .leading, spacing: 2) {
                    Text("All titles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                    Text("\(data.stats.titleCount.formatted()) · A–Z grid with filters and the scrubber")
                        .font(.system(size: 13))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background { ModuleSurface(radius: 22) }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var stack: some View {
        HStack(spacing: -12) {
            ForEach(data.stack) { item in
                PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w92"), size: CGSize(width: 30, height: 44))
                    .frame(width: 30, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.2)))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
        }
        .padding(.leading, data.stack.isEmpty ? 0 : 2)
        .accessibilityHidden(true)
    }
}
