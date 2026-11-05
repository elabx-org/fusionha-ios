import SwiftUI
import FusionhaKit

/// The title's versions as W1 cards side by side (mock kit `vcard`, two per
/// row): the version's T5 badge and its tier ("HD-1080p", or the edition's
/// name), "n/m" for a series, the
/// one-ink rail, then size and state. Tapping a card opens Files at that
/// version.
struct V2TitleVersionStrip: View {
    @Environment(DetailStore.self) private var store
    let versions: [V2TitleVersion]
    /// The open Duo's narrower column: smaller type.
    var small = false

    var body: some View {
        let rows = stride(from: 0, to: versions.count, by: 2).map { Array(versions[$0..<min($0 + 2, versions.count)]) }
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(rows[index]) { version in
                        Button { open(version) } label: {
                            V2TitleVersionCard(version: version, small: small)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.97))
                    }
                    if rows[index].count == 1, versions.count > 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func open(_ version: V2TitleVersion) {
        store.scope = DetailScope(tier: version.edition.tier.rawValue, version: version.edition.versionKey)
        store.tab = .files
    }
}

/// One version card.
struct V2TitleVersionCard: View {
    let version: V2TitleVersion
    var small = false
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                EditionBadge(tier: version.edition.tier, state: version.state, showsCount: false)
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count = version.count {
                    Text(verbatim: count)
                        .font(.system(size: small ? 14 : 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                }
            }
            RailBarV2(have: version.have, aired: version.aired, total: version.total, rest: version.rest)
                .padding(.top, 8)
            Text(version.line)
                .font(.system(size: 12))
                .foregroundStyle(muted)
                .lineLimit(1)
                .padding(.top, 5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ModuleSurface(radius: 16) }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(version.edition.label), \(version.state.spoken). \(version.line)")
        .accessibilityHint("Shows this version's files")
    }

    /// The version's name (an edition such as "Director's Cut") or its tier
    /// (mock `vcard`: "HD-1080p" / "UHD-2160p"), never the profile.
    private var name: String {
        let key = version.edition.versionKey
        if !key.isEmpty { return key }
        return version.edition.tier == .hd ? "HD-1080p" : "UHD-2160p"
    }
}
