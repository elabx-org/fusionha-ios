import SwiftUI
import FusionhaKit

/// Settings › Indexers: the admin-only Cloudflare solver (web
/// `FlareSolverrCard`, fusionha 0.4.213). Letterboxd lists and watchlists are
/// public pages behind Cloudflare; a challenge retries through FlareSolverr
/// when one is set. `flaresolverr_url` is admin-only to read too (others get
/// null). Test sends no body: it only ever tests the SAVED address.
struct FlareSolverrCard: View {
    @Environment(AppModel.self) private var model
    @State private var saved = ""
    @State private var url = ""
    @State private var error: String?
    @State private var result: FlareSolverrTest?
    @State private var testing = false
    @State private var saving = false

    private var isAdmin: Bool { model.me?.isAdmin == true }
    private var dirty: Bool { url.trimmingCharacters(in: .whitespaces) != saved }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloudflare solver").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
            Text("Letterboxd lists and watchlists are read from public web pages that sit behind Cloudflare. RSS diaries never need this.")
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            if isAdmin { editor } else {
                Label("Only an admin can see or change this address. You can manage indexers, but the solver address is hidden from your account.",
                      systemImage: "lock")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim)
            }
        }
        .fetchCard()
        .task(id: isAdmin) { if isAdmin { await load() } }
    }

    @ViewBuilder private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FlareSolverr address").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
            TextField("http://flaresolverr:8191", text: $url)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
                .settingsField("FlareSolverr address")
            Text("Optional. Used only when Letterboxd shows a Cloudflare challenge. Only letterboxd.com addresses are ever sent to it. It may live on your LAN.")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
        }
        HStack(spacing: 8) {
            Button("Clear") { url = ""; Task { await save("") } }
                .buttonStyle(.web(.ghost))
                .disabled((url.isEmpty && saved.isEmpty) || saving)
            Button(saving ? "Saving…" : "Save") { Task { await save(url.trimmingCharacters(in: .whitespaces)) } }
                .buttonStyle(.web(.ghost))
                .disabled(!dirty || saving)
            Spacer()
            Button(testing ? "Testing…" : "Test") { Task { await test() } }
                .buttonStyle(.web())
                .disabled(dirty || saved.isEmpty || testing)
                .accessibilityHint(dirty ? "Save first. Test checks the saved address only." : (saved.isEmpty ? "Add an address first." : ""))
        }
        if let error { Text(error).font(.system(size: 12.5)).foregroundStyle(Theme.danger) }
        if testing {
            Label("Testing… Asking the saved address to solve a test page. Up to 20 seconds.", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 12.5)).foregroundStyle(Theme.grab)
        } else if let result {
            Label(resultText(result), systemImage: result.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12.5)).foregroundStyle(result.ok ? Theme.done : Theme.stuck)
        }
        Text("Test takes no input: it only ever tests the saved address, so it can’t be used to probe other hosts.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
    }

    private func resultText(_ r: FlareSolverrTest) -> String {
        if r.ok {
            let seconds = String(format: "%.1f", Double(r.elapsedMs ?? 0) / 1000)
            return "Working. FlareSolverr answered and solved a test page in \(seconds) s. Letterboxd lists that hit a Cloudflare challenge will retry through it."
        }
        switch r.reason {
        case "timeout": return "It answered, but the test page timed out after 20 s. The solver may be busy or its browser is stuck."
        case "failed": return "It answered, but couldn’t solve the test page. Check the FlareSolverr logs."
        default: return "Couldn’t reach it. Nothing answered at the saved address. Check the address and that the container is running."
        }
    }

    private func load() async {
        guard let client = model.client, let settings = try? await client.settings() else { return }
        saved = settings["flaresolverr_url"]?.string ?? ""
        url = saved
    }

    private func save(_ next: String) async {
        guard let client = model.client else { return }
        saving = true
        defer { saving = false }
        error = nil
        result = nil
        do {
            let fresh = try await client.updateSettings(["flaresolverr_url": .string(next)])
            saved = fresh["flaresolverr_url"]?.string ?? next
            url = saved
        } catch {
            var status: Int?
            if case .http(let code, _)? = error as? APIError { status = code }
            self.error = status == 422 ? "Enter an http:// or https:// address with no user name, query or fragment." : "Couldn’t save. Try again."
        }
    }

    private func test() async {
        guard let client = model.client else { return }
        testing = true
        defer { testing = false }
        do {
            result = try await client.testFlareSolverr()
        } catch {
            result = FlareSolverrTest(ok: false, reason: "unreachable")
        }
    }
}
