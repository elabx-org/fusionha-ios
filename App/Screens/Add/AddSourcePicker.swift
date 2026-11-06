import SwiftUI
import FusionhaKit

/// Find's source switch: a compact segmented capsule of the providers' own
/// marks (memory provider-marks), the selection the kind tabs' cream wash
/// (`SegmentedPills`), never the provider's hue. TVDB is shown but dimmed
/// without a key, so people learn it exists.
struct AddSourcePicker: View {
    @Binding var source: MetadataSource
    /// Movies only search TMDB.
    let showsTvdb: Bool
    let tvdbConfigured: Bool
    @Namespace private var indicator
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        HStack(spacing: 10) {
            Text("Search")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
            HStack(spacing: 0) {
                segment(.tmdb)
                if showsTvdb { segment(.tvdb) }
            }
            .padding(3)
            .glassEffect(.regular.interactive(), in: Capsule())
            .fixedSize()
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.selection, trigger: source)
    }

    private func segment(_ value: MetadataSource) -> some View {
        let selected = source == value
        let locked = value == .tvdb && !tvdbConfigured
        return Button {
            withAnimation(motion ? Motion.indicator : nil) { source = value }
        } label: {
            ProviderMark(provider: value == .tmdb ? "tmdb" : "tvdb", size: 16)
                .opacity(locked ? 0.4 : selected ? 1 : 0.7)
                .padding(.horizontal, 14)
                .frame(minWidth: 64, minHeight: 38)
                .background {
                    if selected {
                        Capsule().fill(Theme.txt.opacity(0.16))
                            .matchedGeometryEffect(id: "source", in: indicator)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(value == .tmdb ? "Search TMDB" : "Search TVDB")
        .accessibilityHint(locked ? "Needs a TVDB key → Settings" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
