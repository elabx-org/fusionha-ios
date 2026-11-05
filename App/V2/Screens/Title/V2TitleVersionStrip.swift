import SwiftUI
import FusionhaKit

/// The title's versions as W1 cards side by side (mock kit `vcard`, two per
/// row): the version's T5 badge and its tier ("HD-1080p", or the edition's
/// name), "n/m" for a series, the
/// one-ink rail, then size and state. Tapping a card selects that version
/// (the page scope: Search, Interactive search, Files, History and Searches
/// follow it) and, from a tab that has no version filter, opens Files at it.
/// Tapping the selected card again goes back to all versions, except on a
/// series' Files tab, which always shows one version (and rings it).
struct V2TitleVersionStrip: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.detailReduceMotion) private var reduce
    let versions: [V2TitleVersion]
    /// The open Duo's narrower column: smaller type.
    var small = false

    var body: some View {
        let selected = versions.count > 1 ? store.v2ShownVersion?.id : nil
        let canDeselect = store.v2TabShowsAllVersions
        let rows = stride(from: 0, to: versions.count, by: 2).map { Array(versions[$0..<min($0 + 2, versions.count)]) }
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    ForEach(rows[index]) { version in
                        Button { open(version) } label: {
                            V2TitleVersionCard(version: version, small: small,
                                               selection: V2VersionSelection(selected: selected, id: version.id),
                                               canDeselect: canDeselect)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.97))
                    }
                    if rows[index].count == 1, versions.count > 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
        .animation(reduce ? nil : .snappy, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func open(_ version: V2TitleVersion) {
        if versions.count > 1, store.focusedVersion?.id == version.id {
            // A series' Files tab has no all-versions view: keep the version.
            if store.v2TabShowsAllVersions { store.scope = .all }
            return
        }
        store.scope = DetailScope(tier: version.edition.tier.rawValue, version: version.edition.versionKey)
        let filtered: Set<DetailTab> = [.files, .history, .searches]
        if !filtered.contains(store.tab) { store.tab = .files }
    }
}

/// A version card's part in the page's selection.
enum V2VersionSelection {
    /// All versions in scope: every card at full strength.
    case all
    case selected
    /// Another version is selected: this one's secondary text steps back.
    case other

    init(selected: Int?, id: Int) {
        guard let selected else { self = .all; return }
        self = selected == id ? .selected : .other
    }
}

/// One version card.
struct V2TitleVersionCard: View {
    let version: V2TitleVersion
    var small = false
    var selection: V2VersionSelection = .all
    /// Tapping the selected card goes back to all versions (not on a
    /// series' Files tab).
    var canDeselect = true
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    /// Quieter, never dim: only the secondary text of an unselected card.
    private var muted: Color { (page?.inkMuted ?? Theme.mut).opacity(selection == .other ? 0.85 : 1) }

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
        .background { ModuleSurface(radius: 16, selected: selection == .selected) }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(version.edition.label), \(version.state.spoken). \(version.line)")
        .accessibilityAddTraits(selection == .selected ? .isSelected : [])
        .accessibilityHint(selection == .selected ? (canDeselect ? "Shows all versions again" : "") : "Selects this version")
    }

    /// The version's name (an edition such as "Director's Cut") or its tier
    /// (mock `vcard`: "HD-1080p" / "UHD-2160p"), never the profile.
    private var name: String {
        let key = version.edition.versionKey
        if !key.isEmpty { return key }
        return version.edition.tier == .hd ? "HD-1080p" : "UHD-2160p"
    }
}
