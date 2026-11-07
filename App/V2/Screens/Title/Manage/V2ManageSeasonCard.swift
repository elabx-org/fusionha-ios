import SwiftUI
import FusionhaKit

/// One season's card (mock frame 1): the header, then, when open, one row
/// per file with a hairline between. Solid content on the wash.
struct V2ManageSeasonCard: View {
    let model: ManageFilesModel
    let group: ManageSeasonGroup
    let showsTierPerRow: Bool
    @Binding var expanded: Bool
    let actions: V2ManageActions
    @Environment(\.pagePalette) private var page
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            V2ManageSeasonHeader(model: model, group: group, expanded: expanded, actions: actions) {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { expanded.toggle() }
            }
            if expanded {
                ForEach(group.lines) { line in
                    Rectangle()
                        .fill(ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight))
                        .frame(height: 0.5)
                        .padding(.leading, 52)
                    V2ManageFileRow(model: model, line: line, showsTier: showsTierPerRow, actions: actions)
                }
            }
        }
        .background { ModuleSurface(radius: 20) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The tri-state select circle: empty, a dash (part of the season), or
/// filled with the accent and a check.
struct V2ManageSelectCircle: View {
    let state: ManageSelectState
    @Environment(\.pagePalette) private var page

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(page?.inkMuted ?? Theme.mut, lineWidth: 1.5)
                .opacity(state == .none ? 1 : 0)
            Circle()
                .fill(Theme.primary)
                .opacity(state == .none ? 0 : 1)
            Image(systemName: state == .partial ? "minus" : "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .opacity(state == .none ? 0 : 1)
        }
        .frame(width: 22, height: 22)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

/// One file fact as a small outline chip in the badge ink; a fact that
/// differs from the season's is outlined in orange and set heavier.
struct V2ManageFactChip: View {
    let fact: ManageFact
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        Text(verbatim: fact.text)
            .font(.system(size: 9.5 * scale, weight: fact.differs ? .semibold : .medium))
            .monospacedDigit()
            .foregroundStyle(fact.differs ? ink.held : ink.label.opacity(0.8))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4.5 * scale)
            .frame(height: MediaBadgeMetrics.height * scale)
            .overlay {
                RoundedRectangle(cornerRadius: MediaBadgeMetrics.radius * scale, style: .continuous)
                    .strokeBorder(fact.differs ? ink.held : ink.secondary, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

/// VoiceOver words for this sheet.
enum V2ManageSpeech {
    /// "32.4 gigabytes".
    static func size(_ bytes: Double) -> String {
        let text = DetailText.bytes(bytes)
        for (unit, word) in [(" TB", " terabytes"), (" GB", " gigabytes"), (" MB", " megabytes"), (" KB", " kilobytes")]
        where text.hasSuffix(unit) {
            return String(text.dropLast(unit.count)) + word
        }
        return text
    }

    static func state(_ state: ManageSelectState) -> String {
        switch state {
        case .none: return "Not selected"
        case .partial: return "Partly selected"
        case .all: return "Selected"
        }
    }

    static func facts(_ facts: [ManageFact]) -> String {
        facts.map { "\($0.kind.spoken) \($0.text)" + ($0.differs ? ", differs from the season" : "") }
            .joined(separator: ", ")
    }
}
