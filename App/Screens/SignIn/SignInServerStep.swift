import SwiftUI
import UIKit
import FusionhaKit

// Step 1 (F2): the server address. One field, one button, and only what
// helps: the servers this phone reached before as explicit "Recent" chips,
// one line about Local Network before the first home-network connect, and
// errors that say what to try.

extension SignInView {
    var serverForm: some View {
        VStack(spacing: 0) {
            LoginField(label: "Server address") {
                TextField("", text: $server,
                          prompt: Text(verbatim: "https://fusionha.example.com").foregroundStyle(Theme.dim))
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($field, equals: .server)
                    .onSubmit { Task { await connect() } }
            } focused: { field == .server }
            .onChange(of: server) { old, new in
                failure = nil
                error = nil
                // A pasted web-app link: keep just the server part.
                if ServerAddress.looksPasted(old: old, new: new) {
                    let cleaned = ServerAddress.clean(new)
                    if cleaned != new { server = cleaned }
                }
            }
            localNetworkNote
            errorText
            if failure == .localNetworkDenied { localNetworkFix }
            GradientSubmit(title: "Connect", workingTitle: "Connecting…", working: working,
                           enabled: !server.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task { await connect() }
            }
            recentChips
        }
    }

    /// Shown before the first connect to a home-network address, so the iOS
    /// prompt that follows isn't a surprise.
    @ViewBuilder
    private var localNetworkNote: some View {
        if failure == nil, !memory.localNetworkExplained,
           let first = ServerAddress.candidates(server).first, ServerAddress.isLocal(first) {
            Label("iOS will ask to find devices on your network. Allow it so fusionha can reach your server.",
                  systemImage: "wifi")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)
                .transition(.opacity)
        }
    }

    private var localNetworkFix: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        } label: {
            Label("Open Settings › fusionha › Local Network", systemImage: "gearshape")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accentText)
        .padding(.bottom, 14)
    }

    /// The servers this phone reached before. Tapping one is the only way a
    /// remembered server is used: nothing connects on its own (fusionha #65).
    @ViewBuilder
    private var recentChips: some View {
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(recents) { recent in
                        Button {
                            server = recent.url.absoluteString
                            Task { await connect() }
                        } label: {
                            Label(recent.label, systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Connect to \(recent.label)")
                        .contextMenu {
                            Button("Forget this server", systemImage: "trash", role: .destructive) {
                                memory.forget(recent.url)
                                recents = memory.recents
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 22)
        }
    }
}

/// Where the person is in first run: Server → Set up → Sign in. Shown only
/// when there are three steps (a fresh server); two need no map.
struct OnboardingSteps: View {
    let current: Int
    let labels: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                if index > 0 {
                    Image(systemName: "chevron.compact.right").foregroundStyle(Theme.dim)
                }
                HStack(spacing: 4) {
                    if index < current { Image(systemName: "checkmark") }
                    Text(label)
                }
                .foregroundStyle(index == current ? Theme.txt : Theme.dim)
                .fontWeight(index == current ? .bold : .medium)
            }
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(labels.count): \(labels[current])")
    }
}
