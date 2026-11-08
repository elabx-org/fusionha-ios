import SwiftUI
import FusionhaKit

/// Anonymous figures for "N asked": counts only, never faces or names.
struct RequestAnonStack: View {
    let count: Int
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(0..<min(max(count, 1), 3), id: \.self) { _ in
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: size, height: size)
                    .background(Theme.panel2, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.panel, lineWidth: 1.5))
            }
        }
        .accessibilityHidden(true)
    }
}

/// "2 others want this" over the versions (web `DemandBanner`).
struct RequestDemandBanner: View {
    let asked: Int

    var body: some View {
        HStack(spacing: 12) {
            RequestAnonStack(count: asked, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(asked) \(asked == 1 ? "other wants" : "others want") this")
                    .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                Text("Me too joins their request. It's free and doesn't use your quota.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .modifier(RequestDemandSurface())
        .accessibilityElement(children: .combine)
    }
}

/// What ticking a version does, on its row.
struct RequestTierTag: View {
    let act: RequestOffer.Act
    let asked: Int

    var body: some View {
        HStack(spacing: 5) {
            if act == .join { RequestAnonStack(count: asked, size: 16) }
            Text(RequestOffer.tag(act, asked: asked))
        }
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(tone)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tone.opacity(0.12), in: Capsule())
        .fixedSize()
    }

    /// v1 marks a join in its accent; v2 keeps the tag in the quiet ink
    /// (the accent is the selection's and the primary's).
    private var tone: Color {
        act == .join && !ProductLook.isV2 ? Theme.i2 : Theme.mut
    }
}

/// The footer's quota pips: "N of M requests left this week".
struct RequestQuotaMini: View {
    let quota: RequestQuota?

    var body: some View {
        if let quota, let limit = quota.limit, limit > 0 {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<limit, id: \.self) { i in
                        // v2: one ink, an empty track for what's left.
                        Capsule().fill(i < quota.used ? (ProductLook.isV2 ? Theme.txt : Theme.i1) : Theme.line)
                            .frame(width: 8, height: 4)
                    }
                }
                Text("\(max(0, limit - quota.used)) of \(limit) requests left this week")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.dim)
        }
    }
}

/// The 409 `quota` answer in place of the footer (web `QuotaWishlistPrompt`):
/// Add to wishlist, Me too on the joinable versions only, or Cancel.
struct RequestQuotaPrompt: View {
    let quota: RequestQuota?
    let pending: Bool
    let wishlistDisabled: Bool
    let joinTiers: [QualityTier]
    let onWishlist: () -> Void
    let onJoinOnly: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(RequestOffer.quotaHeadline(limit: quota?.limit), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.txt)
            Text(RequestOffer.quotaBody(resetsAt: quota?.resetsAt))
                .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            if !joinTiers.isEmpty {
                Text("Me too on \(joinTiers.map(\.chipLabel).joined(separator: " + ")) is free. It goes through with either choice below.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            ActFlow(spacing: 8, lineSpacing: 8) {
                if ProductLook.isV2 {
                    // v2: the accent glass primary, the rest plain glass.
                    Button("Add to wishlist", action: onWishlist)
                        .buttonStyle(.glassProminent).tint(Theme.primary)
                        .disabled(pending || wishlistDisabled)
                    if !joinTiers.isEmpty {
                        Button(joinOnlyTitle, action: onJoinOnly).buttonStyle(.glass).disabled(pending)
                    }
                    Button("Cancel", action: onCancel).buttonStyle(.glass).disabled(pending)
                } else {
                    Button("Add to wishlist", action: onWishlist)
                        .buttonStyle(.discover(.primary))
                        .disabled(pending || wishlistDisabled)
                    if !joinTiers.isEmpty {
                        Button(joinOnlyTitle, action: onJoinOnly)
                            .buttonStyle(.discover(.subtle))
                            .disabled(pending)
                    }
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.discover(.ghost))
                        .disabled(pending)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .modifier(RequestQuotaSurface())
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityAddTraits(.isHeader)
    }

    private var joinOnlyTitle: String {
        "Me too on \(joinTiers.map { $0 == .uhd ? "4K" : "HD" }.joined(separator: " + ")) only"
    }
}

/// The demand banner's surface: v1's premiere wash, v2's grouped card.
private struct RequestDemandSurface: ViewModifier {
    func body(content: Content) -> some View {
        if ProductLook.isV2 {
            content.background(Theme.txt.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content.actWash(Theme.premiere, radius: 12, base: Theme.card)
        }
    }
}

/// The quota prompt's surface: v1's amber wash, v2's glass card (it takes
/// the footer bar's place, and the bar is glass).
private struct RequestQuotaSurface: ViewModifier {
    func body(content: Content) -> some View {
        if ProductLook.isV2 {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content.actWash(Theme.miss, radius: 12, base: Theme.card)
        }
    }
}
