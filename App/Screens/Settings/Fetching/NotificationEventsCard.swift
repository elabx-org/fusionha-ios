import SwiftUI
import FusionhaKit

/// Settings › Notifications › Events (web A10 event matrix): every kind the
/// server lists, each Immediate, Daily digest or Off (digest only where the
/// kind allows it), and the daily digest preview with when it goes out.
/// Loads and saves on its own, one kind per write.
struct NotificationEventsCard: View {
    @Environment(AppModel.self) private var model
    @State private var prefs: [NotificationPreferenceItem] = []
    @State private var digest: DigestPreview?
    @State private var failed: String?

    private static let meta: [String: (label: String, hint: String, sev: Color)] = [
        "grab": ("Grabbed", "A release was sent to the download client", Theme.grab),
        "import": ("Imported", "A file was imported into the library", Theme.done),
        "upgrade": ("Upgrade found", "A better release replaced an existing file", Theme.grab),
        "manual_required": ("Manual import required", "A finished download is waiting for you to pick the file", Theme.miss),
        "failed": ("Download failed", "A grab or import failed", Theme.danger),
        "needs_attention": ("Needs attention", "A manual import or a stuck item needs you", Theme.miss),
        "retargeted": ("Re-routed", "An imported file was moved to the version that matches its real resolution", Theme.premiere),
        "request_available": ("Request available", "A title someone requested is now downloaded", Theme.anime),
        "request_made": ("New request", "A user submitted a new media request", Theme.anime),
        "request_update": ("Request update", "An approver approved, declined or changed one of your requests", Theme.anime),
        "issue_update": ("Issue update", "An issue you reported or joined was resolved", Theme.anime),
        "issue_auto_fixed": ("Issue auto-fixed", "fusionha confirmed a problem and repaired it (dead copy, missing episodes, Plex rescan)", Theme.done),
        "self_service_action": ("Self-service action taken", "A user started a fix themselves: a search, a rescan or a version request", Theme.grab),
        "issue_needs_you": ("Issue needs you", "Inconclusive check, a fix that failed twice, or a report from a client without checks", Theme.miss),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let failed {
                Text(failed).font(.footnote).foregroundStyle(Theme.danger).padding(.vertical, 10)
            }
            ForEach(Array(prefs.filter { $0.retired != true }.enumerated()), id: \.element.eventKind) { index, p in
                if index > 0 { Divider().overlay(Theme.line) }
                row(p)
            }
            if let digest {
                Divider().overlay(Theme.line)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily digest · \(digest.digestTime)" + (digest.pending > 0 ? " · \(digest.pending) waiting" : ""))
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(digest.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                    Text(digest.body).font(.system(size: 12)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
                    if digest.sample { Text("A sample: nothing is waiting for your digest.").font(.caption).foregroundStyle(Theme.dim) }
                    if digest.heldByQuietHours == true { Text("Held by quiet hours.").font(.caption).foregroundStyle(Theme.miss) }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
        .task { await load() }
    }

    private func row(_ p: NotificationPreferenceItem) -> some View {
        let m = Self.meta[p.eventKind] ?? (p.eventKind.replacingOccurrences(of: "_", with: " ").capitalized, "", Theme.dim)
        let delivery = p.delivery ?? (p.enabled ? "IMMEDIATE" : "OFF")
        return HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(m.sev).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(m.label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let a = p.audience, a != "operational" {
                        Text("· \(a == "admin" ? "admins" : "requestors")").font(.system(size: 11)).foregroundStyle(Theme.dim)
                    }
                }
                if !m.hint.isEmpty {
                    Text(m.hint).font(.system(size: 12)).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Menu {
                Button("Immediate") { set(p.eventKind, "IMMEDIATE") }
                if p.digestAllowed == true { Button("Daily digest") { set(p.eventKind, "DIGEST") } }
                Button("Off") { set(p.eventKind, "OFF") }
            } label: {
                GlassMenuLabel(title: delivery == "DIGEST" ? "Digest" : delivery == "OFF" ? "Off" : "Immediate")
            }
            .accessibilityLabel("\(m.label) delivery")
        }
        .padding(.vertical, 10)
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            prefs = try await client.notificationPreferences().preferences
            failed = nil
        } catch {
            failed = ErrorCopy.message(for: error, fallback: "Couldn’t load the events.")
        }
        digest = try? await client.digestPreview()
    }

    private func set(_ kind: String, _ delivery: String) {
        Task {
            guard let client = model.client else { return }
            do {
                prefs = try await client.setNotificationDelivery(event: kind, delivery: delivery).preferences
                digest = try? await client.digestPreview()
            } catch {
                model.toast(ErrorCopy.message(for: error), title: "Couldn’t change the event", variant: .error)
            }
        }
    }
}
