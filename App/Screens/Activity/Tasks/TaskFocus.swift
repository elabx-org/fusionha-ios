import SwiftUI

// The `?focus=<run_id>` deep link on Tasks (web `useFocusFlash`): the target
// row scrolls into view and flashes once; a recent run also opens its trail.

enum TaskFocus {
    /// The scroll id a run row carries, distinct from the stack's group ids.
    static func scrollId(_ runId: Int) -> String { "task-run-\(runId)" }
}

/// A one-off accent ring that fades out, or a static ring under Reduce Motion
/// that clears after a moment.
struct TaskFocusFlash: ViewModifier {
    let active: Bool
    @Environment(\.actReduceMotion) private var reduce
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Theme.accentText, lineWidth: 2)
                    .opacity(lit ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .task(id: active) {
                guard active else { return }
                lit = true
                try? await Task.sleep(for: .milliseconds(reduce ? 1600 : 400))
                if reduce { lit = false } else { withAnimation(.easeOut(duration: 1.2)) { lit = false } }
            }
    }
}

extension View {
    func taskFocusFlash(_ active: Bool) -> some View { modifier(TaskFocusFlash(active: active)) }
}
