import SwiftUI
import FusionhaKit

/// Settings → Access → Public access (`PublicAccessPanel.tsx`): the read-only
/// Demo visitor card with its power toggle, and the Configure demo sheet
/// (instance banner, enable, access method, credentials, sample-library
/// lifecycle and auto-reset). Gated on `system.admin`.
struct PublicAccessPanel: View {
    @Environment(AppModel.self) private var model
    @State private var status: DemoStatus?
    @State private var error: String?
    @State private var updating = false
    @State private var configuring = false
    @State private var toaster = FetchToaster()
    @State private var confirm: FetchConfirm?

    private var canAdmin: Bool {
        guard let me = model.me else { return true }
        return me.isAdmin || (me.permissions ?? []).contains("system.admin")
    }

    var body: some View {
        FetchingPage(slug: "publicaccess", toaster: toaster, confirm: $confirm, refresh: load) {
            if !canAdmin {
                FetchEmpty(text: "You do not have permission to manage public access.")
            } else {
                Text("A sample library a visitor can explore read-only, with no account of their own — no data from your real library is ever shown.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .settingsReveal()
                if let status {
                    visitorCard(status).fetchReveal(1)
                } else {
                    FetchLoading(error: error)
                }
            }
        }
        .task { if canAdmin { await load() } }
        .sheet(isPresented: $configuring) {
            DemoConfigSheet(status: $status, toaster: toaster)
        }
    }

    private func visitorCard(_ data: DemoStatus) -> some View {
        let on = data.demoMode
        let blocked = data.realLibraryPresent == true
        let sub = !on
            ? (blocked ? "Blocked — this instance has a real library" : "Not shown on the login screen")
            : (data.demoRequireCredentials ? "Signs in as “\(data.demoUsername ?? "")”" : "Open · no credentials")
        return HStack(spacing: 14) {
            Text("DV")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.mut)
                .frame(width: 40, height: 40)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                FetchFlow(spacing: 6) {
                    Text("Demo visitor").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    DemoBadge(text: "Viewer", color: Theme.mut, background: Theme.panel2, dot: true)
                    DemoBadge(text: "PUBLIC", color: Theme.indigo, background: Theme.indigo.opacity(0.15), size: 11)
                    if data.demoInstanceEnv == true {
                        DemoBadge(text: "DEDICATED", color: Theme.i2, background: Theme.i2.opacity(0.15), size: 11)
                    }
                    DemoBadge(text: on ? "Live" : "Off", color: on ? Theme.done : Theme.dim,
                              background: (on ? Theme.done : Theme.dim).opacity(0.14), dot: true)
                }
                Text(sub).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                FetchIconButton(systemName: "slider.horizontal.3", label: "Configure demo") { configuring = true }
                FetchIconButton(systemName: "power",
                                label: blocked ? "This instance has a real library — demo mode is only for a dedicated demo instance"
                                    : (on ? "Turn demo off" : "Turn demo on"),
                                tint: on ? Theme.done : nil) { togglePower(data) }
                    .disabled(updating || (!on && blocked))
                    .symbolEffect(.bounce, value: on)
            }
        }
        .padding(15)
        .background(Theme.card.mix(with: Theme.i2, by: 0.04), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(on ? Theme.i2.opacity(0.35) : Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .opacity(on ? 1 : 0.72)
        .animation(.easeOut(duration: 0.16), value: on)
    }

    private func togglePower(_ data: DemoStatus) {
        if !data.demoMode && data.realLibraryPresent == true {
            toaster.show("This instance has a real library. Spin up a separate instance with FUSIONHA_DEMO_INSTANCE=1.",
                         title: "Demo mode is blocked here", tone: .error)
            return
        }
        guard let client = model.client else { return }
        updating = true
        Task {
            defer { updating = false }
            do {
                status = try await client.updateDemo(["demo_mode": .bool(!data.demoMode)])
            } catch {
                toaster.show(error.settingsMessage, title: "Could not update demo mode", tone: .error)
            }
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            status = try await client.demoStatus()
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error.settingsMessage
        }
    }
}

/// Role / status / tag pill on the demo row.
private struct DemoBadge: View {
    let text: String
    let color: Color
    let background: Color
    var dot = false
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text).font(.system(size: size, weight: .bold)).tracking(size == 11 ? 0.3 : 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, size == 11 ? 8 : 9)
        .padding(.vertical, 2.5)
        .background(background, in: Capsule())
        .fixedSize()
    }
}
