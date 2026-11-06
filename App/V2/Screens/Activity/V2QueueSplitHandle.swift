import SwiftUI
import FusionhaKit

/// The grip on the hairline between the live queue and the overview on the
/// flat open Duo (owner on build 805: the queue was stuck in the narrow
/// column and not adjustable). The same pill as the title's split handle
/// (`V2SplitGrip`); dragging moves the hairline live and letting go keeps
/// the share for Activity on this device (`V2QueueView.queueShare`). Both
/// sides keep at least a folded column (`QueueDuoRuleV2.queueWidth`).
/// VoiceOver: adjustable, a tenth of the display a step.
struct V2QueueSplitHandle: View {
    /// The pane's width.
    let width: CGFloat
    /// The queue column's width now.
    let queueWidth: CGFloat
    /// The share while the finger is down; nil at rest.
    @Binding var dragShare: Double?
    let commit: (Double) -> Void
    @Environment(\.motionEnabled) private var motion
    @State private var start: CGFloat?

    var body: some View {
        V2SplitGrip(held: start != nil, motion: motion)
            .frame(width: 44, height: 140)
            .contentShape(Rectangle())
            .gesture(drag)
            .sensoryFeedback(.selection, trigger: start != nil)
            .accessibilityElement()
            .accessibilityLabel("Queue width")
            .accessibilityValue("\(Int((Double(queueWidth / max(width, 1)) * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.1 : -0.1
                commit(clamped(Double(queueWidth / max(width, 1)) + step))
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let from = start ?? queueWidth
                if start == nil { start = queueWidth }
                dragShare = Double((from + value.translation.width) / max(width, 1))
            }
            .onEnded { _ in
                if let share = dragShare { commit(clamped(share)) }
                start = nil
                dragShare = nil
            }
    }

    /// The share the rule would actually lay out (so a drag past either
    /// limit is stored as the limit).
    private func clamped(_ share: Double) -> Double {
        let w = Double(width)
        return QueueDuoRuleV2.queueWidth(width: w, share: share, bookPose: false) / max(w, 1)
    }
}
