import SwiftUI
import FusionhaKit

/// `GET /system/secrets/status`, held for the Security panel and its sheets.
/// Polls every 2 s while an encrypt pass or a rotation runs.
@MainActor
@Observable
final class SecurityStatusStore {
    private(set) var status: SecretsStatus?
    var error: String?
    /// A rotation finished while the panel was open: offer the new key.
    var rotationFinished = false
    let client: APIClient?

    init(client: APIClient?) { self.client = client }

    func load() async {
        guard let client else { return }
        do {
            apply(try await client.secretsStatus())
            error = nil
        } catch {
            if status == nil { self.error = SecretsErrorCopy.message(for: error) }
        }
    }

    func apply(_ fresh: SecretsStatus) {
        if status?.isRotating == true, !fresh.isRotating, fresh.state == "ok" { rotationFinished = true }
        status = fresh
    }
}

/// Settings › Security (web `security/SecurityPanel`): encryption at rest for
/// every stored secret, plus visitor IP recording and retention. Admins only.
struct SecurityAdminSettingsPanel: View {
    @Environment(AppModel.self) private var model
    @State private var store: SecurityStatusStore?

    var body: some View {
        SettingsForm(slug: "security") {
            if model.me?.isAdmin == false {
                SettingsLoadingRow(error: "Only an admin can view this.")
            } else if let store {
                SecurityAdminBody(store: store)
            } else {
                SettingsLoadingRow()
            }
        }
        .task {
            guard store == nil, model.me?.isAdmin != false else { return }
            let s = SecurityStatusStore(client: model.client)
            store = s
            await s.load()
        }
        .refreshable { await store?.load() }
        .task(id: store?.status?.isBusy == true) {
            guard let store, store.status?.isBusy == true else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                await store.load()
            }
        }
    }
}

private struct SecurityAdminBody: View {
    let store: SecurityStatusStore

    var body: some View {
        if let s = store.status {
            if s.isLocked {
                SecurityLockedSections(status: s, store: store)
            } else {
                SecurityKeySections(status: s, store: store)
                if !s.unreadable.isEmpty { SecurityUnreadableSection(status: s, store: store) }
                SecurityBackupsSection(status: s, store: store)
            }
        } else if let error = store.error {
            SettingsLoadingRow(error: error)
        } else {
            SettingsLoadingRow()
        }
        SecurityVisitorIpSection()
    }
}

/// The card's tone colour (web `TONE_COLOR`).
extension SecretsTone {
    var color: Color {
        switch self {
        case .ok: return Theme.done
        case .busy: return Theme.i1
        case .locked: return Theme.miss
        case .neutral: return Theme.unmonitored
        }
    }
}

extension SecretsHeroIcon {
    var symbol: String {
        switch self {
        case .shield: return "checkmark.shield"
        case .lock: return "lock"
        case .rotate: return "arrow.clockwise"
        }
    }
}

/// The hero row: a tinted icon tile, a title and its sub line.
struct SecurityHeroRow: View {
    let symbol: String
    let tone: Color
    let title: String
    let sub: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 40, height: 40)
                .background(tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                Text(sub).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}
