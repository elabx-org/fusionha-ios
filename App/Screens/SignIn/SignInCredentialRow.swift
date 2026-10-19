import SwiftUI
import FusionhaKit

/// One sign-in method (web `CredentialRow`): glyph, label + primary pill, the
/// provider / external-id line, then Set-primary, the admin-only Move, the
/// active switch and Detach.
struct SignInCredentialRow: View {
    let credential: UserCredential
    /// The identity's last active method: detach / disable would lock them out.
    let lastActive: Bool
    let working: Bool
    let canMove: Bool
    let onPrimary: () -> Void
    let onActive: (Bool) -> Void
    let onMove: () -> Void
    let onDetach: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SignInProviderTile(provider: credential.provider, size: 32, radius: 9)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(credential.providerLabel).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                    if credential.isPrimary { SignInPill(word: "primary") }
                }
                Text("\(credential.provider) · \(credential.externalId ?? credential.displayHandle ?? "")")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !credential.isPrimary {
                Button(action: onPrimary) { Image(systemName: "star").font(.system(size: 14)) }
                    .foregroundStyle(Theme.mut)
                    .disabled(working)
                    .accessibilityLabel("Set \(credential.providerLabel) as primary")
            }
            if canMove {
                Button(action: onMove) { Image(systemName: "arrow.left.arrow.right").font(.system(size: 14)) }
                    .foregroundStyle(Theme.mut)
                    .disabled(working)
                    .accessibilityLabel("Move \(credential.providerLabel) to another identity")
            }
            Toggle("\(credential.providerLabel) active", isOn: Binding(get: { credential.isActive }, set: onActive))
                .labelsHidden()
                .tint(Theme.done)
                .disabled(working || (lastActive && credential.isActive))
            Button(action: onDetach) { Image(systemName: "trash").font(.system(size: 14)) }
                .foregroundStyle(Theme.danger)
                .disabled(working || lastActive)
                .accessibilityLabel("Detach \(credential.providerLabel)")
        }
        .padding(.vertical, 4)
    }
}

/// The small done-tinted word pill ("primary", "Linked").
struct SignInPill: View {
    let word: String

    var body: some View {
        Text(word)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.done)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(Theme.done.opacity(0.15), in: Capsule())
    }
}

/// The icon tile for a provider: key (password), the Plex mark, or a globe (OIDC).
struct SignInProviderTile: View {
    let provider: String
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch provider {
        case "plex":
            Image("plex-mark").renderingMode(.template).resizable().scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundStyle(Theme.plexGold)
                .frame(width: size, height: size)
                .background(Theme.plexGold.opacity(size > 40 ? 0.18 : 0.15), in: shape)
        case "local":
            Image(systemName: "key").font(.system(size: size * 0.42))
                .foregroundStyle(Theme.mut)
                .frame(width: size, height: size)
                .background(Theme.panel2, in: shape)
        default:
            Image(systemName: "globe").font(.system(size: size * 0.42))
                .foregroundStyle(Theme.done)
                .frame(width: size, height: size)
                .background(Theme.done.opacity(0.15), in: shape)
        }
    }
}
