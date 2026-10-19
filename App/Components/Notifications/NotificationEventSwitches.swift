import SwiftUI
import FusionhaKit

/// The event list with one on/off switch per kind (web `EventsSection`): only
/// the kinds the server lists for this user, minus the admin delivery card's
/// kinds; the retired `issue_reported` shows read-only and off. Loads and
/// saves on its own, one kind per write.
struct NotificationEventSwitches: View {
    @Environment(AppModel.self) private var model
    /// Where a failed write is announced; the app toast when nil.
    var notify: ((_ message: String, _ ok: Bool) -> Void)?
    @State private var prefs: [NotificationPreferenceItem] = []
    @State private var loaded = false
    @State private var failed: String?
    /// Switches flipped but not yet confirmed by the server (optimistic).
    @State private var pending: [String: Bool] = [:]

    /// Web `adminDeliveryRows`: digestible admin kinds live in their own card.
    private var rows: [NotificationPreferenceItem] {
        prefs.filter { !($0.audience == "admin" && $0.digestAllowed == true && $0.retired != true) }
    }

    /// Audience tags only help when the caller sees both kinds (an admin does).
    private var mixed: Bool { rows.contains { $0.audience == "admin" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let failed {
                Text(failed).font(.system(size: 12)).foregroundStyle(Theme.danger)
            } else if !loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            ForEach(rows, id: \.eventKind) { row($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await load() }
    }

    private func row(_ p: NotificationPreferenceItem) -> some View {
        let meta = NotificationEventMeta.of(p.eventKind)
        let retired = p.retired == true
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(meta.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let tag = tag(p, retired: retired) {
                        Text(tag).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                    if retired {
                        FetchPill(text: "Retired", tone: .off)
                    } else if NotificationEventMeta.newKinds.contains(p.eventKind) {
                        FetchPill(text: "New", tone: .accent)
                    }
                }
                let hint = retired ? NotificationEventMeta.retiredHint : meta.hint
                if !hint.isEmpty {
                    Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle(meta.label, isOn: binding(p, retired: retired))
                .labelsHidden()
                .tint(Theme.indigo)
                .disabled(retired)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .actWash(retired ? nil : meta.sev, radius: 13)
        .opacity(retired ? 0.6 : 1)
    }

    private func tag(_ p: NotificationPreferenceItem, retired: Bool) -> String? {
        if p.audience == "requester" && mixed { return "· requestors" }
        if p.audience == "admin" && !retired { return "· admins" }
        return nil
    }

    private func binding(_ p: NotificationPreferenceItem, retired: Bool) -> Binding<Bool> {
        Binding(get: { retired ? false : pending[p.eventKind] ?? p.enabled }, set: { set(p.eventKind, enabled: $0) })
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            prefs = try await client.notificationPreferences().preferences
            failed = nil
        } catch {
            failed = ErrorCopy.message(for: error, fallback: "Couldn’t load the events.")
        }
        loaded = true
    }

    private func set(_ kind: String, enabled: Bool) {
        guard let client = model.client else { return }
        pending[kind] = enabled
        Task {
            do {
                prefs = try await client.setNotificationPreference(event: kind, enabled: enabled).preferences
            } catch {
                let message = NotificationEventMeta.writeError(error)
                if let notify { notify(message, false) } else { model.toast(message, variant: .error) }
            }
            pending[kind] = nil
        }
    }
}
