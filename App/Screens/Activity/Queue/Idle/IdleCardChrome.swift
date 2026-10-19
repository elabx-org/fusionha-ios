import SwiftUI
import FusionhaKit

// The empty queue's shared card chrome (web `idle-shared.module.css`): a solid
// card with a hairline, the section header with its link, and the calm state.
// Content, not glass. Tints are solid washes (no gradients).

extension View {
    /// A solid card; `tint` lays a faint solid wash of a status colour over it.
    func idleCard(tint: Color? = nil, base: Color = Theme.card, radius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            shape.fill(base).overlay { if let tint { shape.fill(tint.opacity(0.07)) } }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Theme.line))
    }
}

/// `.chd`: icon + title, a muted subtitle, and the trailing link.
struct IdleCardHeader: View {
    let icon: String
    let title: String
    var sub: Text?
    let link: String
    var compact = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label {
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt)
            } icon: {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .labelStyle(IdleHeaderLabelStyle())
            .fixedSize()
            if let sub {
                sub.font(.system(size: 12)).foregroundStyle(Theme.mut)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(link)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.top, compact ? 3 : 4)
    }
}

private struct IdleHeaderLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) { configuration.icon; configuration.title }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }
}

/// `.calm`: a quiet line, optionally with a round icon and a bold lead.
struct IdleCalm: View {
    var icon: String?
    var tint: Color = Theme.unaired
    var title: String?
    let message: String
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                }
                Text(message).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.top, 6)
        .padding(.bottom, compact ? 16 : 18)
    }
}

/// A hairline between list rows inside an idle card.
struct IdleRowDivider: View {
    var body: some View {
        Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 1)
    }
}
