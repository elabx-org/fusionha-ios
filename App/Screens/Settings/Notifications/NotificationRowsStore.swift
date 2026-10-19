import SwiftUI
import FusionhaKit

/// The server-listed preference rows split into the admin delivery card and
/// the Events switches, with optimistic writes (web `useNotificationRows` +
/// `useDeliveryWrite`). One source for both cards and the digest sample.
@MainActor
@Observable
final class NotificationRowsStore {
    private(set) var prefs: [NotificationPreferenceItem] = []
    private(set) var loaded = false
    private(set) var failed: String?
    private(set) var digest: DigestPreview?
    /// Switches flipped but not yet confirmed by the server.
    private(set) var pendingEnabled: [String: Bool] = [:]
    /// Deliveries chosen but not yet confirmed by the server.
    private(set) var pendingDelivery: [String: String] = [:]

    var adminRows: [NotificationPreferenceItem] { NotificationRowRules.adminDelivery(prefs) }
    var eventRows: [NotificationPreferenceItem] { NotificationRowRules.events(prefs) }

    func load(_ client: APIClient?) async {
        guard let client else { return }
        do {
            prefs = try await client.notificationPreferences().preferences
            failed = nil
        } catch {
            failed = ErrorCopy.message(for: error, fallback: "Couldn’t load the events.")
        }
        loaded = true
        await refreshDigest(client)
    }

    func refreshDigest(_ client: APIClient?) async {
        guard let client, !adminRows.isEmpty else { digest = nil; return }
        digest = try? await client.digestPreview()
    }

    func enabled(_ row: NotificationPreferenceItem) -> Bool {
        pendingEnabled[row.eventKind] ?? row.enabled
    }

    func delivery(_ row: NotificationPreferenceItem) -> String {
        pendingDelivery[row.eventKind] ?? NotificationRowRules.delivery(row)
    }

    func toggle(_ kind: String, enabled: Bool, model: AppModel) {
        guard let client = model.client else { return }
        pendingEnabled[kind] = enabled
        Task {
            do {
                prefs = try await client.setNotificationPreference(event: kind, enabled: enabled).preferences
            } catch {
                model.toast(NotificationEventMeta.writeError(error), variant: .error)
            }
            pendingEnabled[kind] = nil
        }
    }

    func choose(_ kind: String, delivery: String, model: AppModel) {
        guard let client = model.client else { return }
        pendingDelivery[kind] = delivery
        Task {
            do {
                prefs = try await client.setNotificationDelivery(event: kind, delivery: delivery).preferences
                await refreshDigest(client)
            } catch {
                model.toast(NotificationEventMeta.writeError(error), variant: .error)
            }
            pendingDelivery[kind] = nil
        }
    }
}
