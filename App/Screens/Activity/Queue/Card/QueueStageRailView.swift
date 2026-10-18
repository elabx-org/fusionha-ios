import SwiftUI
import FusionhaKit

/// The card's stage rail (web `StageRail`, mock v4): decypharr's nodes, a
/// seam, then fusionha's own import node. Finished nodes are just a green
/// tick (their names are in the VoiceOver label and a long-press); the node
/// you are waiting on carries its words ("Import held").
struct QueueStageRailView: View {
    let model: QueueRailModel
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(model.nodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    Capsule()
                        .fill(model.nodes[index - 1].state == .done ? Theme.done.opacity(0.5) : Theme.line)
                        .frame(width: 10, height: 1.5)
                }
                NodeView(node: node, showsLabel: node.state != .done)
            }
            Rectangle().fill(Theme.line).frame(width: 1, height: 18).padding(.horizontal, 4)
            NodeView(node: model.importNode, showsLabel: true, fusionha: true)
        }
        .font(.system(size: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stages: " + (model.nodes + [model.importNode]).map(\.label).joined(separator: ", "))
    }

    private struct NodeView: View {
        let node: QueueRailNode
        let showsLabel: Bool
        var fusionha = false
        @State private var pulse = false
        @Environment(\.actReduceMotion) private var reduce

        var body: some View {
            HStack(spacing: 6) {
                dot
                if showsLabel {
                    Text(node.label + (node.state == .off ? " · off" : ""))
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                    if node.state == .active {
                        Text(node.count ?? "working…").foregroundStyle(Theme.grab).monospacedDigit()
                    }
                }
            }
            .help(node.tip ?? node.label)
            .contextMenu { if let tip = node.tip { Text(tip) } else { Text(node.label) } }
        }

        private var labelColor: Color {
            switch node.state {
            case .todo, .off: return Theme.dim
            case .fail: return Theme.danger
            case .active where fusionha: return Theme.done
            default: return Theme.txt
            }
        }

        @ViewBuilder
        private var dot: some View {
            ZStack {
                switch node.state {
                case .done:
                    Circle().fill(Theme.done.opacity(0.22))
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.done)
                case .fail:
                    Circle().fill(Theme.danger.opacity(0.22))
                    Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.danger)
                case .held:
                    Circle().strokeBorder(Theme.stuck, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
                    Image(systemName: "pause.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.stuck)
                case .active:
                    let tint = fusionha ? Theme.done : Theme.grab
                    Circle().strokeBorder(tint, lineWidth: 1.5)
                    Circle().fill(tint).frame(width: 7, height: 7)
                        .opacity(pulse ? 0.35 : 1)
                        .onAppear {
                            guard !reduce else { return }
                            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
                        }
                case .todo:
                    Circle().strokeBorder(Theme.dim.opacity(0.6), lineWidth: 1.5)
                case .off:
                    Circle().strokeBorder(Theme.dim.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2]))
                }
            }
            .frame(width: 22, height: 22)
        }
    }
}
