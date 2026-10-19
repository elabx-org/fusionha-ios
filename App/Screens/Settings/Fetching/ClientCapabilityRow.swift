import SwiftUI
import FusionhaKit

/// Under a download client (web A8 `CapabilityCard`): whether fusionha can
/// check files with it (decypharr's verify API), when that was last checked,
/// and Re-check now.
struct ClientCapabilityRow: View {
    let clientId: Int
    @Environment(AppModel.self) private var model
    @State private var cap: ClientCapabilities?
    @State private var checking = false

    var body: some View {
        Group {
            if let cap {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: cap.state == .available ? "checkmark.shield" : cap.state == .absent ? "shield.slash" : "questionmark.circle")
                        .foregroundStyle(tone(cap))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("File checks · \(cap.chip)").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(cap.note).font(.system(size: 11.5)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
                        Text(ServerTime.parse(cap.verifyCheckedAt).map { "Checked \($0.formatted(.relative(presentation: .named)))" } ?? "Never checked")
                            .font(.system(size: 11)).foregroundStyle(Theme.dim)
                        if let err = cap.lastProbeError { Text(err).font(.system(size: 11)).foregroundStyle(Theme.danger) }
                    }
                    Spacer(minLength: 0)
                    Button { Task { await probe() } } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.txt)
                    .disabled(checking)
                    .accessibilityLabel("Re-check now")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .actWash(tone(cap), radius: 11)
            }
        }
        .task { cap = try? await model.client?.clientCapabilities(clientId: clientId) }
    }

    private func tone(_ c: ClientCapabilities) -> Color {
        switch c.state {
        case .available: return Theme.done
        case .absent: return Theme.dim
        case .unknown: return Theme.miss
        }
    }

    private func probe() async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do { cap = try await client.probeClientCapabilities(clientId: clientId) } catch {
            model.toast(ErrorCopy.message(for: error, fallback: "Couldn’t re-check. Try again."), variant: .error)
        }
    }
}
