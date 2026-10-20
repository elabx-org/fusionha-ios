import SwiftUI
import FusionhaKit

/// StatusBadge `check`: an emerald tick on a frosted dark plate.
struct DoneBadge: View {
    var body: some View {
        GeometryReader { geo in
            Image(systemName: "checkmark")
                .font(.system(size: geo.size.width * 0.36, weight: .bold))
                .foregroundStyle(Theme.done)
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Theme.bg.opacity(0.5), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.txt.opacity(0.16)))
        }
    }
}

struct StepIcon: View {
    @Environment(\.motionEnabled) private var motion
    let status: SetupStepStatus
    @State private var spin = false

    var body: some View {
        switch status {
        case .done, .skipped, .failed:
            Image(systemName: status == .failed ? "xmark" : "checkmark")
                .font(.system(size: status == .failed ? 7.5 : 9, weight: .bold))
                .foregroundStyle(status == .failed ? Theme.danger : Theme.done)
                .frame(width: 18, height: 18)
                .background(Theme.bg.opacity(0.5), in: Circle())
                .overlay(Circle().strokeBorder(Theme.txt.opacity(0.16)))
        case .running:
            Circle()
                .trim(from: 0, to: motion ? 0.75 : 1)
                .stroke(Theme.grab, style: StrokeStyle(lineWidth: 1.5, dash: motion ? [] : [3, 2]))
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .onAppear {
                    guard motion else { return }
                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true }
                }
                .padding(.top, 1)
        default:
            Circle()
                .strokeBorder(Theme.line, lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .padding(.top, 1)
        }
    }
}
