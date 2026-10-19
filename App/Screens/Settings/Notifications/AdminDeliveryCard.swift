import SwiftUI
import FusionhaKit

/// "Issues & self-service · admins" (web `AdminDeliveryCard`): each
/// digestible admin kind as Immediate / Daily digest / Off, with the server's
/// default under it. Hidden when the caller has none of these kinds.
struct AdminDeliveryCard: View {
    @Environment(AppModel.self) private var model
    let store: NotificationRowsStore

    var body: some View {
        let rows = store.adminRows
        if !rows.isEmpty {
            NotifSec("Issues & self-service · admins")
            NotifCard {
                ForEach(Array(rows.enumerated()), id: \.element.eventKind) { index, row in
                    if index > 0 { Divider().overlay(Theme.line) }
                    deliveryRow(row)
                }
            }
        }
    }

    private func deliveryRow(_ row: NotificationPreferenceItem) -> some View {
        let meta = NotificationEventMeta.of(row.eventKind)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                NotifSeverityDot(color: meta.sev).padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(meta.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        if NotificationEventMeta.newKinds.contains(row.eventKind) { NotifKindPill(kind: .new) }
                    }
                    if !meta.hint.isEmpty {
                        Text(meta.hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let def = NotificationRowRules.defaultLabel(row.defaultDelivery) {
                        Text(def).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                }
            }
            Picker("\(meta.label) delivery", selection: Binding(
                get: { store.delivery(row) },
                set: { store.choose(row.eventKind, delivery: $0, model: model) }
            )) {
                Text("Immediate").tag("IMMEDIATE")
                Text("Daily digest").tag("DIGEST")
                Text("Off").tag("OFF")
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 12)
    }
}

/// The Events switches (web `EventsSection`): one per kind the server lists
/// outside the admin delivery card; the retired kind shows read-only and off.
struct NotificationEventsList: View {
    @Environment(AppModel.self) private var model
    let store: NotificationRowsStore

    /// Audience tags only help when the caller sees both kinds (an admin does).
    private var mixed: Bool { store.eventRows.contains { $0.audience == "admin" } }

    var body: some View {
        NotifSec("Events")
        NotifCard {
            if let failed = store.failed {
                Text(failed).font(.footnote).foregroundStyle(Theme.danger).padding(.vertical, 10)
            } else if !store.loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            ForEach(Array(store.eventRows.enumerated()), id: \.element.eventKind) { index, row in
                if index > 0 { Divider().overlay(Theme.line) }
                eventRow(row)
            }
        }
    }

    private func eventRow(_ row: NotificationPreferenceItem) -> some View {
        let meta = NotificationEventMeta.of(row.eventKind)
        let retired = row.retired == true
        return HStack(spacing: 10) {
            NotifSeverityDot(color: meta.sev)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(meta.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let tag = tag(row, retired: retired) {
                        Text(tag).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                    if retired {
                        NotifKindPill(kind: .retired)
                    } else if NotificationEventMeta.newKinds.contains(row.eventKind) {
                        NotifKindPill(kind: .new)
                    }
                }
                let hint = retired ? NotificationEventMeta.retiredHint : meta.hint
                if !hint.isEmpty {
                    Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle(meta.label, isOn: Binding(
                get: { retired ? false : store.enabled(row) },
                set: { store.toggle(row.eventKind, enabled: $0, model: model) }
            ))
            .labelsHidden()
            .tint(Theme.indigo)
            .disabled(retired)
        }
        .padding(.vertical, 10)
        .opacity(retired ? 0.7 : 1)
    }

    private func tag(_ row: NotificationPreferenceItem, retired: Bool) -> String? {
        if row.audience == "requester" && mixed { return "· requestors" }
        if row.audience == "admin" && !retired { return "· admins" }
        return nil
    }
}
