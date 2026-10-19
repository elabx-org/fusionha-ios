import SwiftUI
import FusionhaKit

// MARK: Empty state (`components/ui/EmptyState`)

struct CalEmptyState: View {
    let message: String
    var quip: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.mut)
                .lineSpacing(13.5 * 0.6 - 3)
            if let quip {
                (Text("— ").foregroundColor(Theme.dim) + Text(quip).italic().foregroundColor(Theme.dim))
                    .font(.system(size: 13.5))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}
