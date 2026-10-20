import SwiftUI
import FusionhaKit

// The login card: the brand block, the step's headline, and the step itself
// (server address, then the sign-in chooser, or the fresh server's setup).

extension SignInView {
    var card: some View {
        VStack(spacing: 0) {
            brand(hero: false)
            header(centered: true)
            content
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        // A Liquid Glass sheet over the living backdrop, darkened so the form reads.
        .glassEffect(.regular.tint(Theme.bg.opacity(0.62)), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.8), radius: 50, y: 36)
        // `.card { animation: riseIn 0.9s }`
        .loginEntrance(.riseIn(0.9), delay: 0)
        .disabled(working)
        .modifier(Nudge(trigger: nudges))
    }

    /// `.title` + `.sub` (centred in the card, left-aligned in split).
    func header(centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 0) {
            if let connected, connected.status.needsSetup {
                OnboardingSteps(current: 1, labels: ["Server", "Set up", "Sign in"])
                    .padding(.bottom, 14)
            }
            Text(connected == nil ? "Find your fusionha" : "Welcome back")
                .font(Theme.display(40))
                .tracking(Theme.displayTracking(40))
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.bottom, 8)
                .loginEntrance(.fadeUp(0.7), delay: 0.42)
            Text(connected == nil ? "The address you open the web app at." : "Sign in to continue")
                .font(.system(size: 15))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(centered ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)
                .loginEntrance(.fadeUp(0.7), delay: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    @ViewBuilder
    var content: some View {
        if let connected {
            if connected.status.needsSetup {
                hint("This server hasn't been set up yet. Create its admin account and connect TMDB here.")
                Button("Set up this server") { settingUp = true }
                    .buttonStyle(ActButtonStyle(kind: .primary, small: false))
                    .padding(.top, 10)
                    .fullScreenCover(isPresented: $settingUp) { SetupWizardView(server: connected.url) }
                Link("Or open the web app", destination: connected.url)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 8)
            } else {
                chooser(url: connected.url, status: connected.status)
                    .frame(maxWidth: .infinity)
                demoSection(url: connected.url, status: connected.status)
            }
        } else {
            serverForm
        }
    }

    /// The brand identity block: logo, the letter-by-letter wordmark, tagline.
    /// The split hero shows it bigger (108pt logo, 20pt wordmark).
    @ViewBuilder
    func brand(hero: Bool) -> some View {
        let showLogo = status?.loginShowLogo ?? true
        let showWordmark = status?.loginShowWordmark ?? false
        let showTagline = status?.loginShowTagline ?? false
        if showLogo || showWordmark || showTagline {
            VStack(spacing: hero ? 14 : 12) {
                if showLogo {
                    LoginLogo(hero: hero)
                }
                if showWordmark {
                    LoginWordmark(size: hero ? 20 : 15)
                }
                if showTagline {
                    Text("Everything you watch. One library, every version.")
                        .font(.system(size: 13.5))
                        .lineSpacing(13.5 * 0.6 - 4)
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                        .loginEntrance(.fadeUp(0.7), delay: 0.56)
                }
            }
            .padding(.bottom, 22)
        }
    }

    @ViewBuilder
    var livingCaption: some View {
        let showWordmark = status?.loginShowWordmark ?? false
        let showTagline = status?.loginShowTagline ?? false
        if showWordmark || showTagline {
            VStack(spacing: 8) {
                if showWordmark { LoginWordmark(size: 15) }
                if showTagline {
                    Text("Everything you watch. One library, every version.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.mut)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 14)
        }
    }

    /// The reached state: which server answered (its host and `/health`
    /// version), and the way back to the address step.
    @ViewBuilder
    var changeServer: some View {
        if let connected {
            Button {
                withAnimation(motionOff ? nil : .snappy) { reset() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                    Text(verbatim: connected.host)
                    Text(verbatim: "· \(connected.version)").foregroundStyle(Theme.dim)
                    Text("·")
                    Text("Change").foregroundStyle(Theme.txt)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Connected to \(connected.host), version \(connected.version). Change server")
        }
    }
}
