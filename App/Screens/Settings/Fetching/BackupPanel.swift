import SwiftUI
import UIKit
import FusionhaKit

/// Settings → Backup (`BackupPanel.tsx`): the scheduled-backup card (the toggle
/// saves instantly; cadence / retention / folder save with "Save schedule") and
/// the archive list with Backup now, Download (to the share sheet) and Delete.
struct BackupPanel: View {
    @Environment(AppModel.self) private var model
    @State private var config: BackupConfig?
    @State private var records: [BackupRecord] = []
    @State private var error: String?
    @State private var intervalText = ""
    @State private var retentionText = ""
    @State private var folderText = ""
    @State private var savingSchedule = false
    @State private var creating = false
    @State private var downloading: String?
    @State private var deleting: String?
    @State private var shareItem: FetchShareItem?
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var dirty: Bool {
        guard let config else { return false }
        return intervalText != String(config.intervalHours)
            || retentionText != String(config.retention)
            || folderText != config.folder
    }

    var body: some View {
        FetchingPage(slug: "backup", toaster: toaster, confirm: $confirm, refresh: load) {
            if let config {
                VStack(alignment: .leading, spacing: 14) {
                    if config.available == false { warning.fetchReveal(0) }
                    scheduleCard(config).fetchReveal(1)
                    listCard(config).fetchReveal(2)
                }
            } else if let error {
                FetchLoading(error: error)
            } else {
                Text("Loading backup settings…")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .padding(.vertical, 24).padding(.horizontal, 4)
            }
        }
        .task { await load() }
        .sheet(item: $shareItem) { item in
            FetchActivityView(url: item.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }

    // MARK: Cards

    private var warning: some View {
        (Text("The ") + Text("pg_dump").font(.system(size: 12, design: .monospaced))
         + Text(" client needed to back up this Postgres database isn’t available in this build. Backups can’t run until it’s installed."))
            .font(.system(size: 13))
            .foregroundStyle(Theme.txt)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.stuck.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.stuck.opacity(0.45)))
    }

    private func scheduleCard(_ config: BackupConfig) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scheduled backup").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("An automatic \(config.backend == "postgres" ? "Postgres" : "SQLite") backup on a fixed cadence. Manual backups always work regardless.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("Enable scheduled backup", isOn: Binding(get: { config.enabled }, set: saveToggle))
                    .labelsHidden()
                    .tint(Theme.indigo)
            }

            HStack(alignment: .top, spacing: 12) {
                field("Every (hours)", text: $intervalText, hint: "24 = daily", numeric: true)
                field("Keep (backups)", text: $retentionText, hint: "older ones are pruned", numeric: true)
            }
            field("Folder", text: $folderText, hint: "absolute path on a mounted volume", numeric: false)

            HStack {
                Spacer()
                Button(savingSchedule ? "Saving…" : "Save schedule", action: saveSchedule)
                    .buttonStyle(BackupPrimaryButtonStyle())
                    .disabled(!dirty || savingSchedule)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
    }

    private func field(_ label: String, text: Binding<String>, hint: String, numeric: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            TextField(label, text: text)
                .font(.system(size: 14, design: numeric ? .default : .monospaced).monospacedDigit())
                .keyboardType(numeric ? .numberPad : .URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 11)
                .frame(height: 38)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous).strokeBorder(Theme.line))
            Text(hint).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listCard(_ config: BackupConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backups").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(records.isEmpty
                         ? "No backups yet in \(config.folder)"
                         : "\(records.count) archive\(records.count == 1 ? "" : "s") in \(config.folder)")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(creating ? "Backing up…" : "Backup now", action: backupNow)
                    .buttonStyle(BackupPrimaryButtonStyle())
                    .disabled(config.available == false || creating)
            }

            if !records.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Divider().overlay(Theme.line) }
                        row(record)
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous).strokeBorder(Theme.line))
    }

    private func row(_ record: BackupRecord) -> some View {
        let manual = record.kind == "manual"
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(record.kind)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(manual ? Theme.indigo : Theme.mut)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background((manual ? Theme.indigo : Theme.mut).opacity(manual ? 0.16 : 0.15), in: Capsule())
                Text(record.id)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack(spacing: 10) {
                Text(Self.when(record.createdAt))
                Text(DatabasePanel.bytes(record.sizeBytes)).monospacedDigit()
                if let version = record.appVersion {
                    Text("v\(version)").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                }
                Spacer(minLength: 6)
                Button {
                    download(record)
                } label: {
                    if downloading == record.id {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("Download")
                    }
                }
                .buttonStyle(.web(.subtle))
                .disabled(downloading != nil)
                .accessibilityLabel("Download \(record.id)")
                Button("Delete") { askDelete(record) }
                    .buttonStyle(.web(.danger))
                    .disabled(deleting != nil)
                    .accessibilityLabel("Delete \(record.id)")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 2)
        .opacity(deleting == record.id ? 0.5 : 1)
    }

    // MARK: Actions

    private func saveToggle(_ enabled: Bool) {
        guard let client = model.client else { return }
        Task {
            do {
                config = try await client.updateBackupConfig(["enabled": .bool(enabled)])
            } catch {
                toaster.show(error.settingsMessage, title: "Could not update backups", tone: .error)
            }
        }
    }

    private func saveSchedule() {
        guard let client = model.client else { return }
        let folder = folderText.trimmingCharacters(in: .whitespaces)
        guard let interval = Int(intervalText.trimmingCharacters(in: .whitespaces)), interval >= 1 else {
            toaster.show("Interval must be at least 1 hour.", tone: .error); return
        }
        guard let retention = Int(retentionText.trimmingCharacters(in: .whitespaces)), retention >= 1 else {
            toaster.show("Keep must be at least 1 backup.", tone: .error); return
        }
        guard folder.hasPrefix("/") else {
            toaster.show("Folder must be an absolute path.", tone: .error); return
        }
        savingSchedule = true
        Task {
            defer { savingSchedule = false }
            do {
                let fresh = try await client.updateBackupConfig([
                    "interval_hours": .int(interval),
                    "retention": .int(retention),
                    "folder": .string(folder),
                ])
                apply(fresh)
                toaster.show("Backup schedule saved.")
            } catch {
                toaster.show(error.settingsMessage, title: "Could not save schedule", tone: .error)
            }
        }
    }

    private func backupNow() {
        guard let client = model.client else { return }
        creating = true
        Task {
            defer { creating = false }
            do {
                let result = try await client.createBackup()
                toaster.show("\(result.backup.id) (\(DatabasePanel.bytes(result.backup.sizeBytes)))", title: "Backup created")
                await loadList()
            } catch {
                toaster.show(error.settingsMessage, title: "Backup failed", tone: .error)
            }
        }
    }

    private func askDelete(_ record: BackupRecord) {
        confirm = FetchConfirm(title: "Delete backup?",
                               message: "\(record.id) will be removed from the backup folder. This can’t be undone.") {
            remove(record)
        }
    }

    private func remove(_ record: BackupRecord) {
        guard let client = model.client else { return }
        deleting = record.id
        Task {
            defer { deleting = nil }
            do {
                try await client.deleteBackup(id: record.id)
                withAnimation(.easeOut(duration: 0.25)) { records.removeAll { $0.id == record.id } }
                await loadList()
            } catch {
                toaster.show(error.settingsMessage, title: "Could not delete backup", tone: .error)
            }
        }
    }

    /// Fetches the archive into a temp file named like the web's `download`
    /// attribute, then hands it to the share sheet (Save to Files, AirDrop …).
    private func download(_ record: BackupRecord) {
        guard let client = model.client else { return }
        downloading = record.id
        Task {
            defer { downloading = nil }
            do {
                let data = try await client.downloadBackup(id: record.id)
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("backups", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let url = dir.appendingPathComponent(record.id)
                try? FileManager.default.removeItem(at: url)
                try data.write(to: url, options: .atomic)
                shareItem = FetchShareItem(url: url)
            } catch {
                toaster.show(error.settingsMessage, title: "Download failed", tone: .error)
            }
        }
    }

    // MARK: Data

    private func apply(_ fresh: BackupConfig) {
        config = fresh
        intervalText = String(fresh.intervalHours)
        retentionText = String(fresh.retention)
        folderText = fresh.folder
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            let fresh = try await client.backupConfig()
            if config == nil || !dirty { apply(fresh) } else { config = fresh }
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = error.settingsMessage
        }
        await loadList()
    }

    private func loadList() async {
        guard let client = model.client else { return }
        if let list = try? await client.backups() { records = list }
    }

    /// The web's `formatWhen`: just now / 5m ago / 3h ago / 2d ago, then the date.
    static func when(_ iso: String) -> String {
        guard let then = FetchFormat.date(iso) else { return iso }
        let secs = Int(Date.now.timeIntervalSince(then).rounded())
        if secs < 60 { return "just now" }
        let mins = Int((Double(secs) / 60).rounded())
        if mins < 60 { return "\(mins)m ago" }
        let hours = Int((Double(mins) / 60).rounded())
        if hours < 24 { return "\(hours)h ago" }
        let days = Int((Double(hours) / 24).rounded())
        if days < 30 { return "\(days)d ago" }
        return then.formatted(date: .numeric, time: .omitted)
    }
}

/// The panel's solid accent button (`.primary`): 13.5/600 on indigo.
private struct BackupPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(Theme.indigo, in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}

struct FetchShareItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// The system share sheet for a downloaded archive (SwiftUI's ShareLink can't be
/// presented after an async download, so this wraps UIActivityViewController).
struct FetchActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
