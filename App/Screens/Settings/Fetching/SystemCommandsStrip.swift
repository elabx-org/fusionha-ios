import SwiftUI
import FusionhaKit

/// The live Commands strip: in-flight runs with a sweeping shimmer.
struct CommandsStrip: View {
    let commands: [SystemCommand]

    var body: some View {
        let running = commands.filter { $0.status == "running" }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Commands").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Text(running.isEmpty ? "Idle" : "\(running.count) running")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.mut)
            }
            if running.isEmpty {
                Text("No commands are running right now.")
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            } else {
                ForEach(running) { command in
                    HStack(spacing: 12) {
                        Text(SystemTaskFormat.label(command.name))
                            .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                            .lineLimit(1)
                        ShimmerTrack()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active commands")
    }
}

private struct ShimmerTrack: View {
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.grab.opacity(0.16))
                if motionOff {
                    Capsule().fill(Theme.grab.opacity(0.55))
                } else {
                    Capsule().fill(Theme.primary)
                        .frame(width: geo.size.width * 0.45)
                        .offset(x: geo.size.width * 0.45 * (phase ? 1.6 : -0.6))
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: phase)
                        .onAppear { phase = true }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}
