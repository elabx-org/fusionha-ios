import SwiftUI
import FusionhaKit

/// The client card's verified line (mock `.s2-cc .ok`): a state dot, whether
/// fusionha can check files with the client and when that was last checked,
/// the client's priority, and Re-check now. The facts are v1's
/// `ClientCapabilityRow` (the list carries them; a missing one is fetched).
struct V2ClientVerifiedLine: View {
    let client: DownloadClientInfo
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @State private var cap: ClientCapabilities?
    @State private var checking = false

    private var current: ClientCapabilities? { cap ?? client.capabilities }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(line)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                if let priority = client.priority {
                    Text("Priority \(priority)").monospacedDigit()
                }
                Button { Task { await probe() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .disabled(checking)
                .accessibilityLabel("Re-check now")
            }
            .font(.footnote)
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            if let err = current?.lastProbeError {
                Text(err).font(.caption).foregroundStyle(Theme.danger).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: client.id) {
            guard client.capabilities == nil else { return }
            cap = try? await model.client?.clientCapabilities(clientId: client.id)
        }
    }

    private var dot: Color {
        guard let state = current?.state else { return Theme.dim }
        switch state {
        case .available: return Theme.done
        case .unknown: return Theme.stuck
        case .absent: return Theme.dim
        }
    }

    /// "API verified 16:38 · file checks on" / "File checks not available" /
    /// "File checks not checked yet".
    private var line: String {
        guard let current else { return "File checks not checked yet" }
        let when = ServerTime.parse(current.verifyCheckedAt).map(Self.time)
        switch current.state {
        case .available: return when.map { "API verified \($0) · file checks on" } ?? "File checks on"
        case .absent: return "File checks not available" + (when.map { " · checked \($0)" } ?? "")
        case .unknown: return "File checks not checked yet"
        }
    }

    /// The time today, else the day and time.
    private static func time(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    private func probe() async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do { cap = try await client.probeClientCapabilities(clientId: self.client.id) } catch {
            model.toast(ErrorCopy.message(for: error, fallback: "Couldn’t re-check. Try again."), variant: .error)
        }
    }
}
