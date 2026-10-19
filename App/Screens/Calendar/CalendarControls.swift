import SwiftUI
import FusionhaKit

// The Calendar's glass controls (the mock's `.views`, `.calbar .nav`, `.kf` and
// `.g36`). Selection is a cream wash or a cream fill, never a status colour.

/// Month · Week · Forecast · Day · Agenda: equal segments on one glass capsule,
/// the selection a sliding cream wash.
struct CalViewSwitcher: View {
    let selection: CalendarViewMode
    var motion = true
    let onSelect: (CalendarViewMode) -> Void
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                let on = mode == selection
                Button {
                    withAnimation(motion ? Motion.indicator : nil) { onSelect(mode) }
                } label: {
                    // Labels shorten (Mo/Wk/Fc/Day/Ag) when the segment is too narrow.
                    ViewThatFits(in: .horizontal) {
                        Text(mode.label).fixedSize()
                        Text(mode.shortLabel).fixedSize()
                    }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? Theme.txt : Theme.mut)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background {
                            if on {
                                Capsule()
                                    .fill(Theme.txt.opacity(0.16))
                                    .matchedGeometryEffect(id: "calendar-view", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// ‹ · Today · › in one glass capsule (`.calbar .nav`).
struct CalNavButtons: View {
    let noun: String
    let onPrev: () -> Void
    /// nil leaves Today to the toolbar (D1).
    let onToday: (() -> Void)?
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPrev) { chevron("chevron.left") }
                .accessibilityLabel("Previous \(noun)")
            if let onToday {
                Button(action: onToday) {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }
            }
            Button(action: onNext) { chevron("chevron.right") }
                .accessibilityLabel("Next \(noun)")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .glassControl()
        .fixedSize()
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .frame(width: 28, height: 36)
            .contentShape(Rectangle())
    }
}

/// All · Series · Movies · Anime (`.kf`): glass chips with the kind dot; the
/// selected one is lit cream with dark text.
struct CalKindChip: View {
    let filter: CalendarMediaFilter
    let on: Bool
    let action: () -> Void

    private var dot: Color? {
        switch filter {
        case .all: return nil
        case .series: return Theme.kindSeries
        case .movies: return Theme.kindMovie
        case .anime: return Theme.kindAnime
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                Text(filter.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(on ? Theme.onInk : Theme.mut)
            }
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.txt).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

