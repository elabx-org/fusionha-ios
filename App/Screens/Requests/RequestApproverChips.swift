import SwiftUI
import FusionhaKit

/// The approver's chips on a pending request's thread (web A7 `RequestChips`):
/// Approve, Decline with reason, Not available yet, and Add 4K (approves with
/// a UHD·4K version added and searched). A decided request shows none.
struct RequestApproverChips: View {
    let request: MediaRequest
    let onDecided: () -> Void
    @Environment(AppModel.self) private var model
    @State private var reject: RejectMode?

    private enum RejectMode: Identifiable {
        case decline, defer_
        var id: Int { self == .decline ? 0 : 1 }
    }

    private var hasUhd: Bool { request.tiers.contains(.uhd) }

    var body: some View {
        ActFlow(spacing: 8, lineSpacing: 8) {
            ActAsyncButton(label: "Approve", systemImage: "checkmark", kind: .primary) {
                await approve(ApproveBody(editions: [], search: true), done: "Request approved")
            }
            Button("Decline with reason", systemImage: "xmark") { reject = .decline }
                .buttonStyle(ActButtonStyle(kind: .danger))
            Button("Not available yet", systemImage: "clock") { reject = .defer_ }
                .buttonStyle(ActButtonStyle(kind: .subtle))
            ActAsyncButton(label: "Add 4K", systemImage: "plus") {
                await approve(ApproveBody(editions: [ApproveEdition(tier: .uhd, rootFolderId: nil, qualityProfileId: nil)], search: true),
                              done: "UHD·4K added and approved")
            }
            .disabled(hasUhd)
            .accessibilityHint(hasUhd ? "Already has a UHD·4K version" : "")
        }
        .sheet(item: $reject) { mode in
            RejectDialog(request: request, deferFirst: mode == .defer_, onDone: onDecided)
        }
    }

    private func approve(_ body: ApproveBody, done: String) async -> Bool {
        guard let client = model.client else { return false }
        do {
            try await client.approveRequest(id: request.id, body: body)
            model.toast(done)
            onDecided()
            return true
        } catch {
            model.toast(ErrorCopy.message(for: error), title: "Could not decide request", variant: .error)
            return false
        }
    }
}
