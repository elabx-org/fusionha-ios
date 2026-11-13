import SwiftUI
import FusionhaKit

/// Add a version's choice rows: tiers, editions, what will be added, and
/// each tier's root folder and profile.
extension AddEditionSheet {
    var tiersRow: some View {
        LabeledContent("Tiers") {
            HStack(spacing: 6) {
                ForEach(QualityTier.ordered, id: \.self) { tier in
                    Toggle(tier.chipLabel, isOn: tierBinding(tier))
                        .toggleStyle(.button)
                        .buttonBorderShape(.capsule)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    /// Ticking a tier seeds its folder and profile; the last tier stays ticked.
    private func tierBinding(_ tier: QualityTier) -> Binding<Bool> {
        Binding(get: { tiers.contains(tier) }, set: { on in
            if on {
                tiers.insert(tier)
                if roots[tier] == nil || profileIds[tier] == nil { reseed(tier) }
            } else if tiers.count > 1 {
                tiers.remove(tier)
                if tier == .uhd { fourK = nil }
            }
        })
    }

    /// A menu of toggles that stays open while you tick (Standard, the
    /// Settings cuts, names used in the library, Custom…).
    var editionsRow: some View {
        LabeledContent("Editions") {
            Menu {
                Toggle(Self.standard, isOn: editionBinding(Self.standard))
                if !presets.isEmpty {
                    Section("Cuts") {
                        ForEach(presets, id: \.self) { Toggle($0, isOn: editionBinding($0)) }
                    }
                }
                if !usedNames.isEmpty {
                    Section("Used in your library") {
                        ForEach(usedNames, id: \.self) { Toggle($0, isOn: editionBinding($0)) }
                    }
                }
                Section {
                    Toggle("Custom…", isOn: customBinding)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(editionsLabel).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.indigo)
            }
            .menuActionDismissBehavior(.disabled)
        }
    }

    private var tickedCount: Int { editions.count + (customOn ? 1 : 0) }

    private func editionBinding(_ name: String) -> Binding<Bool> {
        Binding(get: { editions.contains(name) }, set: { on in
            if on { editions.insert(name) } else if tickedCount > 1 { editions.remove(name) }
        })
    }

    private var customBinding: Binding<Bool> {
        Binding(get: { customOn }, set: { on in
            if on || tickedCount > 1 { customOn = on }
        })
    }

    private var editionsLabel: String {
        var names = (editions.contains(Self.standard) ? [Self.standard] : [])
            + (presets + usedNames).filter { editions.contains($0) }
        if customOn { names.append("Custom…") }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    var customRow: some View {
        LabeledContent("Custom edition name") {
            TextField(isSeries ? "e.g. Remastered" : "e.g. Final Cut", text: $customEdition)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
    }

    var willAddRow: some View {
        let plan = self.plan
        return LabeledContent("Will add") {
            VStack(alignment: .trailing, spacing: 2) {
                Text(plan.freshText)
                    .foregroundStyle(plan.fresh.isEmpty ? Theme.mut : Theme.txt)
                if let skipped = plan.skippedText {
                    Text(skipped).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// Root folder, folder name and profile; one root and one profile per
    /// tier ticked (a 4K version usually lives in its own folder).
    @ViewBuilder
    var locationRows: some View {
        let several = tierList.count > 1
        ForEach(tierList, id: \.self) { tier in
            Picker(several ? "Root folder · \(tier.badgeLetters)" : "Root folder", selection: rootBinding(tier)) {
                if roots[tier] == nil { Text("—").tag(Int?.none) }
                ForEach(store.roots) { Text($0.path).tag(Int?.some($0.id)) }
            }
        }
        LabeledContent("Folder name") {
            TextField(defaultFolder, text: $folderName)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
        }
        ForEach(tierList, id: \.self) { tier in
            Text(previewPath(tier))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.mut)
        }
        ForEach(tierList, id: \.self) { tier in
            Picker(several ? "Quality profile · \(tier.badgeLetters)" : "Quality profile", selection: profileBinding(tier)) {
                if profileIds[tier] == nil { Text("—").tag(Int?.none) }
                ForEach(profiles) { Text($0.name).tag(Int?.some($0.id)) }
            }
        }
    }

    private func rootBinding(_ tier: QualityTier) -> Binding<Int?> {
        Binding(get: { roots[tier] }, set: { roots[tier] = $0 })
    }

    private func profileBinding(_ tier: QualityTier) -> Binding<Int?> {
        Binding(get: { profileIds[tier] }, set: { profileIds[tier] = $0 })
    }

    private var defaultFolder: String {
        detail.year.map { "\(detail.title) (\(String($0)))" } ?? detail.title
    }

    private func previewPath(_ tier: QualityTier) -> String {
        let root = store.roots.first { $0.id == roots[tier] }?.path ?? "—"
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        return root + "/" + (folder.isEmpty ? defaultFolder : folder)
    }

    func reseed(_ tier: QualityTier) {
        let slot = defaults.first { $0.profileKind == DetailVocab.profileKind(detail) && $0.tier == tier }
        roots[tier] = slot?.rootFolderId ?? DetailVocab.defaultRoot(tier, detail: detail, roots: store.roots)
        profileIds[tier] = slot?.qualityProfileId ?? DetailVocab.defaultProfile(tier, profiles: profiles)
    }

    /// The Settings cuts and the Add defaults, fetched every time the sheet
    /// appears. They used to ride the draft with `seeded`: a fold or a re-host
    /// mid-fetch kept the empty lists for good, so Edition showed only
    /// Standard and Custom… (owner, IMG_8014).
    func loadVocabulary() async {
        guard let client = store.client else { return }
        async let d = try? client.addDefaults()
        async let e = try? client.editionDefinitions()
        let (slots, definitions) = await (d, e)
        if let slots { defaults = slots }
        if let definitions {
            presets = definitions.filter { $0.enabled != false }.map(\.name).filter { $0 != Self.standard }
        }
    }

    /// The first-open choices, once per opening (a restored draft keeps the
    /// user's). Waits for the vocabulary, so a cancelled fetch seeds next time.
    func seed() {
        guard !seeded, !Task.isCancelled else { return }
        seeded = true
        minimumAvailability = store.settings?.defaultMovieMinimumAvailability ?? "released"
        let start = preset.tier ?? (detail.editions.contains { $0.tier == .uhd } ? .hd : .uhd)
        tiers = [start]
        if let version = preset.version, !version.isEmpty {
            if presets.contains(version) || usedNames.contains(version) {
                editions = [version]
            } else {
                editions = []
                customOn = true
                customEdition = version
            }
        }
        reseed(start)
    }
}
