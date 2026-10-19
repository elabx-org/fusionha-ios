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
        .actWash(Theme.premiere, radius: 12, base: Theme.card)
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
        .foregroundStyle(act == .join ? Theme.i2 : Theme.mut)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background((act == .join ? Theme.i2 : Theme.mut).opacity(0.12), in: Capsule())
        .fixedSize()
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
                        Capsule().fill(i < quota.used ? Theme.i1 : Theme.line).frame(width: 8, height: 4)
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
                Button("Add to wishlist", action: onWishlist)
                    .buttonStyle(.discover(.primary))
                    .disabled(pending || wishlistDisabled)
                if !joinTiers.isEmpty {
                    Button("Me too on \(joinTiers.map { $0 == .uhd ? "4K" : "HD" }.joined(separator: " + ")) only", action: onJoinOnly)
                        .buttonStyle(.discover(.subtle))
                        .disabled(pending)
                }
                Button("Cancel", action: onCancel)
                    .buttonStyle(.discover(.ghost))
                    .disabled(pending)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .actWash(Theme.miss, radius: 12, base: Theme.card)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityAddTraits(.isHeader)
    }
}
