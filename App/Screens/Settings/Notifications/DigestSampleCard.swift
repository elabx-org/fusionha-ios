import SwiftUI
import FusionhaKit

/// The caller's pending daily digest, or a sample, drawn as the push it will
/// be (web `DigestSampleCard`). Shown only when the admin delivery card is.
struct DigestSampleCard: View {
    let preview: DigestPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NotifSec("\(preview.sample ? "Sample" : "Pending") · daily digest at \(preview.digestTime)")
            HStack(alignment: .top, spacing: 12) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(width: 36, height: 36)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(preview.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(preview.digestTime)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Theme.dim)
                    }
                    Text(preview.body)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: 440, alignment: .leading)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            if preview.heldByQuietHours == true {
                Text("Held until quiet hours end")
                    .font(.system(size: 12)).foregroundStyle(Theme.miss)
                    .padding(.top, 8)
            }
            if preview.sample {
                Text("Sample text. Nothing is queued for a digest today, so this preview uses example counts.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }
}

/// The daily digest time (web `DigestTimeInput`): edits stay local and are
/// written once, after a one-second pause, so spinning the wheel saves once.
struct DigestTimePicker: View {
    let value: String
    let commit: (String) -> Void
    @State private var draft: Date?

    private var shown: Date { draft ?? Self.date(from: value) }

    var body: some View {
        DatePicker("Daily digest time", selection: Binding(get: { shown }, set: { draft = $0 }),
                   displayedComponents: .hourAndMinute)
            .labelsHidden()
            .tint(Theme.indigo)
            .task(id: draft) {
                guard let draft else { return }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                let c = Calendar.current.dateComponents([.hour, .minute], from: draft)
                let next = NotificationRowRules.formatTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
                if next != value { commit(next) }
                self.draft = nil
            }
    }

    static func date(from hhmm: String?, fallbackHour: Int = 18) -> Date {
        let parsed = NotificationRowRules.parseTime(hhmm)
        return Calendar.current.date(bySettingHour: parsed?.hour ?? fallbackHour, minute: parsed?.minute ?? 0,
                                     second: 0, of: .now) ?? .now
    }

    static func hhmm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return NotificationRowRules.formatTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}
