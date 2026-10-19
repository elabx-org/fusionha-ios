import SwiftUI
import FusionhaKit

/// Admin "Grouping & timing" (web `ChannelPolicySection`): delivery grouping,
/// quiet hours, the daily digest time, then the digest sample and the
/// rotate-keys footer.
struct ChannelPolicyCard<Sample: View>: View {
    let settings: WebPushSettings?
    let rotating: Bool
    let update: ([String: SettingsJSON]) -> Void
    let rotate: () -> Void
    @ViewBuilder let sample: () -> Sample

    var body: some View {
        NotifSec("Grouping & timing")
        NotifCard {
            grouping
            Divider().overlay(Theme.line)
            quietHours
            Divider().overlay(Theme.line)
            digestTime
        }
        sample()
        HStack {
            Button(rotating ? "Rotating…" : "Rotate keys", action: rotate)
                .buttonStyle(.web(.ghost))
                .disabled(rotating)
            Spacer()
        }
        .padding(.top, 18)
    }

    private var grouping: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label: "Delivery", description: "How multiple events are bundled")
            Picker("Delivery grouping", selection: Binding(get: { settings?.grouping ?? "group_by_title" },
                                                           set: { update(["grouping": .string($0)]) })) {
                Text("Immediate").tag("immediate")
                Text("Group by title").tag("group_by_title")
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 10)
    }

    private var quietHours: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FieldLabel(label: "Quiet hours", description: "Hold non-urgent pushes overnight")
                Spacer()
                Toggle("Enable quiet hours", isOn: Binding(get: { settings?.quietHoursEnabled ?? false },
                                                           set: { update(["quiet_hours_enabled": .bool($0)]) }))
                    .labelsHidden().tint(Theme.indigo)
            }
            HStack(spacing: 8) {
                timePicker("Quiet hours start", key: "quiet_hours_start", value: settings?.quietHoursStart, hour: 22)
                Text("→").foregroundStyle(Theme.dim).accessibilityHidden(true)
                timePicker("Quiet hours end", key: "quiet_hours_end", value: settings?.quietHoursEnd, hour: 7)
                Spacer()
            }
        }
        .padding(.vertical, 10)
    }

    private var digestTime: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Daily digest at").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                NotifKindPill(kind: .new)
            }
            Text("One push a day with everything set to Daily digest · server time zone · held during quiet hours")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
            DigestTimePicker(value: settings?.digestTime ?? NotificationRowRules.defaultDigestTime) {
                update(["digest_time": .string($0)])
            }
        }
        .padding(.vertical, 10)
    }

    private func timePicker(_ label: String, key: String, value: String?, hour: Int) -> some View {
        DatePicker(label, selection: Binding(get: { DigestTimePicker.date(from: value, fallbackHour: hour) },
                                             set: { update([key: .string(DigestTimePicker.hhmm($0))]) }),
                   displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(Theme.indigo)
    }
}
