import SwiftUI
import FusionhaKit

/// A file's choice as a tag in the page's ink: Import filled, Keep yours
/// outlined, Skip quiet; an undecided file says Decide in the held ink.
struct MIChoiceTag: View {
    let choice: MIChoice?
    var committed = false

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .fixedSize()
    }

    private var text: String {
        if committed { return "Imported" }
        switch choice {
        case .importFile?, .assign?: return "Import"
        case .keep?: return "Keep yours"
        case .skip?: return "Skip"
        case .rematch?: return "Re-match"
        case nil: return "Decide"
        }
    }

    private var ink: Color {
        if committed { return Theme.mut }
        switch choice {
        case .importFile?, .assign?: return Theme.bg
        case nil: return Theme.stuckText
        default: return Theme.txt
        }
    }

    private var fill: Color {
        if committed { return .clear }
        switch choice {
        case .importFile?, .assign?: return Theme.txt.opacity(0.88)
        case .skip?: return Theme.txt.opacity(0.08)
        default: return .clear
        }
    }

    private var stroke: Color {
        if committed { return .clear }
        switch choice {
        case .keep?, .rematch?: return Theme.txt.opacity(0.45)
        case nil: return Theme.stuck
        default: return .clear
        }
    }
}
