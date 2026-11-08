import SwiftUI
import FusionhaKit

/// "Season 4 · 9 other files are fine   Show".
struct V2FixOthersLine: View {
    let text: String
    let show: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            Spacer(minLength: 8)
            Button("Show", action: show)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .accessibilityHint("Shows every file in Manage episodes")
        }
        .padding(.horizontal, 6)
    }
}

/// The model's note (what an action did, or why it didn't), as Manage episodes shows it.
struct V2FixNoteLine: View {
    let note: ManageFilesModel.Note
    @Environment(\.pagePalette) private var page

    var body: some View {
        Label(note.text, systemImage: note.failed ? "exclamationmark.circle" : "checkmark.circle")
            .font(.footnote.weight(.medium))
            .foregroundStyle(note.failed ? Theme.dangerText : (page?.ink ?? Theme.txt))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background { ModuleSurface(radius: 14) }
    }
}

/// An empty or failed state, with an optional way on.
struct V2FixMessage: View {
    let text: String
    let action: (title: String, run: () -> Void)?
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(spacing: 12) {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
