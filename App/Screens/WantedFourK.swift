import SwiftUI
import FusionhaKit

// Wanted · 4K Available (`FourKCard`, `FourKRail`, `FourKSeasonRow` in
// routes/Wanted.tsx) and its "Add edition" sheet (AddEditionDialog preset to UHD).

private let fourKSourceLabels: [String: String] = [
    "rss": "RSS", "manual": "Manual search", "observed": "Auto search", "probe": "Probe", "check": "Checked",
]

private func fourKSources(_ sources: [String]?, _ source: String?) -> [String] {
    let raw = (sources?.isEmpty == false ? sources : source.map { [$0] }) ?? []
    var out: [String] = []
    for s in raw { if let label = fourKSourceLabels[s], !out.contains(label) { out.append(label) } }
    return out
}

/// The `via RSS + Auto search` provenance pill.
private struct FourKProvenance: View {
    let labels: [String]
    var body: some View {
        Text("via \(labels.joined(separator: " + "))")
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(QualityTier.uhd.color.mix(with: Theme.mut, by: 0.25))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(QualityTier.uhd.color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(QualityTier.uhd.color.opacity(0.24)))
            .lineLimit(1)
            .fixedSize()
    }
}

/// One HD-owned / 4K-available coverage rail; the fill grows in over 0.9s.
private struct FourKRail: View {
    let tier: QualityTier
    let fraction: Double
    let meta: String
    @Environment(\.actReduceMotion) private var reduce
    @State private var grown = false

    var body: some View {
        let rc = tier == .hd ? Theme.done : Theme.grab
        HStack(spacing: 7) {
            Text(tier.pill)
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(tier.color)
                .frame(minWidth: 24)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tier.color.opacity(0.45)))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(rc).frame(width: geo.size.width * fraction * (reduce || grown ? 1 : 0))
                }
            }
            .frame(height: 6)
            HStack(spacing: 4) {
                Image(systemName: tier == .hd ? "checkmark" : "circle.fill").font(.system(size: 8, weight: .heavy))
                Text(meta)
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(rc)
            .lineLimit(1)
            .fixedSize()
        }
        .onAppear {
            guard !reduce, !grown else { return }
            withAnimation(ActMotion.reveal(0.9)) { grown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.chipLabel) \(tier == .hd ? "owned" : "available"), \(meta)")
    }
}

struct WantedFourKCard: View {
    let item: FourKAvailableItem
    let onAdd: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var checking = false

    private func rail(_ tier: QualityTier) -> (Double, String) {
        if let total = item.totalSeasons {
            let have = tier == .hd ? (item.hdOwnedSeasons ?? 0) : (item.uhdAvailableSeasons ?? 0)
            let pct = total > 0 ? min(1, Double(have) / Double(total)) : 0
            return (pct, "\(have) / \(total) season\(total == 1 ? "" : "s")")
        }
        if tier == .hd { return (1, "Owned · 1 file") }
        return (1, "Available · \(ActFmt.plural(item.seenCount, "release"))")
    }

    var body: some View {
        let kind = WantedLogic.kind(isAnime: item.isAnime, kind: item.kind)
        let provenance = fourKSources(item.sources, item.source)
        let hd = rail(.hd)
        let uhd = rail(.uhd)
        ActGroupCard(wash: QualityTier.uhd.color, base: Theme.panel, defaultOpen: true, hasTrailing: false) {
            ActPoster(url: item.posterUrl, title: item.title, size: .md)
        } title: {
            ActFlow(spacing: 9, lineSpacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .bold)).tracking(-0.15).foregroundStyle(Theme.txt)
                WantedKindPill(kind: kind)
                Text("4K spotted").font(.system(size: 12.5, weight: .bold)).foregroundStyle(QualityTier.uhd.color)
            }
        } trailing: {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 7) {
                            FourKRail(tier: .hd, fraction: hd.0, meta: hd.1)
                            FourKRail(tier: .uhd, fraction: uhd.0, meta: uhd.1)
                        }
                        .frame(maxWidth: 230, alignment: .leading)
                        if let tags = item.formatTags, !tags.isEmpty {
                            ActFlow(spacing: 6, lineSpacing: 6) {
                                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in formatTag(tag) }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metaLine)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.dim)
                        if !provenance.isEmpty { FourKProvenance(labels: provenance) }
                        actions.padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)
                if let seasons = item.seasons, !seasons.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(seasons.enumerated()), id: \.element.id) { index, season in
                            if index > 0 {
                                Rectangle().fill(Theme.line).frame(height: 1).mask(
                                    HStack(spacing: 3) { ForEach(0..<120, id: \.self) { _ in Rectangle().frame(width: 3) } })
                            }
                            seasonRow(season)
                        }
                    }
                    .background(Theme.panel2)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
        }
    }

    private var metaLine: String {
        var parts = [item.seenCount == 1 ? "Seen once" : "Seen \(item.seenCount)×"]
        if let size = item.bestSize, size > 0 { parts.append(ActFmt.bytes(size)) }
        if let last = item.lastSeenAt { parts.append("last \(ActFmt.relative(last))") }
        return parts.joined(separator: " · ")
    }

    private func formatTag(_ tag: FormatTag) -> some View {
        let color: Color = {
            switch tag.kind {
            case "quality": return QualityTier.uhd.color
            case "hdr": return Theme.miss
            case "audio": return Theme.done
            case "group": return Theme.edition
            default: return Theme.mut
            }
        }()
        return Text(tag.label)
            .font(.system(size: 10.5, weight: .semibold, design: tag.kind == "group" ? .monospaced : .default))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3)))
            .lineLimit(1)
            .fixedSize()
    }

    private var actions: some View {
        HStack(spacing: 6) {
            iconButton(label: "Open in library") {
                Image(systemName: "arrow.up.right.square")
            } action: { model.open(item.id) }
            iconButton(label: "Check for 4K now", busy: checking) {
                Image(systemName: "magnifyingglass")
            } action: { check() }
            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("Add").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color(hex: 0x08131A))
                .padding(.horizontal, 12)
                .frame(minWidth: 40, minHeight: 40)
                .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add edition")
        }
    }

    private func iconButton<Icon: View>(label: String, busy: Bool = false, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if busy { ProgressView().controlSize(.mini).tint(Theme.mut) } else { icon().font(.system(size: 15)) }
            }
            .foregroundStyle(Theme.mut)
            .frame(width: 40, height: 40)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }

    private func check() {
        checking = true
        Task {
            defer { checking = false }
            do {
                let result = try await model.client?.checkFourK(itemId: item.id)
                let message = result?.message ?? ""
                toaster.show(message.isEmpty ? "Checked \(item.title) for 4K." : message,
                             tone: result?.foundUhd == true ? .success : .info)
            } catch {
                toaster.error(error)
            }
        }
    }

    private func seasonRow(_ season: FourKSeason) -> some View {
        let sources = fourKSources(nil, season.source)
        return HStack(spacing: 12) {
            Text(String(format: "S%02d", season.seasonNumber))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .frame(minWidth: 58, alignment: .leading)
            Text(season.bestReleaseName ?? "Seen \(season.seenCount)×")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let q = season.bestQuality {
                Text(ActFmt.quality(q)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim).fixedSize()
            }
            if !sources.isEmpty { FourKProvenance(labels: sources) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Add edition (AddEditionDialog, preset UHD·4K)

struct WantedAddEditionSheet: View {
    let item: FourKAvailableItem
    let onAdded: () -> Void
    let onCancel: () -> Void
    @Environment(AppModel.self) private var model
    @State private var tier: QualityTier = .uhd
    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfile] = []
    @State private var defaults: [AddDefaultSlot] = []
    @State private var rootId = 0
    @State private var profileId = 0
    @State private var monitored = true
    @State private var searchNow = true
    @State private var saving = false
    @State private var error: String?

    private var resolvedKind: String { item.isAnime ? "anime" : item.kind.rawValue }

    private var kindProfiles: [QualityProfile] {
        let matching = profiles.filter { p in
            guard let k = p.mediaKind?.lowercased(), k != "any" else { return true }
            return k == resolvedKind || (resolvedKind == "anime" && k == "series")
        }
        return matching.isEmpty ? profiles : matching
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tier", selection: $tier) {
                        Text(QualityTier.hd.chipLabel).tag(QualityTier.hd)
                        Text(QualityTier.uhd.chipLabel).tag(QualityTier.uhd)
                    }
                    Picker("Root folder", selection: $rootId) {
                        if rootId == 0 { Text("—").tag(0) }
                        ForEach(roots) { r in Text(r.path).font(.system(.body, design: .monospaced)).tag(r.id) }
                    }
                    Picker("Quality profile", selection: $profileId) {
                        if profileId == 0 { Text("—").tag(0) }
                        ForEach(kindProfiles) { p in Text(p.name).tag(p.id) }
                    }
                } footer: {
                    Text("\(item.title) · a new quality edition, tracked independently")
                }
                Section {
                    Toggle(monitored ? "Monitored" : "Unmonitored", isOn: $monitored)
                    Toggle("Search for releases now", isOn: $searchNow)
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.danger).font(.system(size: 13)) }
                }
            }
            .tint(Theme.indigo)
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationTitle("Add an edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if saving { ProgressView() } else { Text("Add edition").bold() }
                    }
                    .disabled(saving || rootId == 0 || profileId == 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.panel)
        .task { await load() }
        .onChange(of: tier) { seed() }
    }

    private func load() async {
        guard let client = model.client else { return }
        async let r = try? client.rootFolders()
        async let p = try? client.qualityProfiles()
        async let d = try? client.addDefaults()
        roots = await r ?? []
        profiles = await p ?? []
        defaults = await d ?? []
        seed()
    }

    /// `resolveTier`: the Add-defaults slot for (kind, tier), else the
    /// path / name heuristics (`edition-defaults.ts`).
    private func seed() {
        let slot = defaults.first(where: { $0.profileKind == resolvedKind && $0.tier == tier })
        let wants4k = tier == .uhd
        func is4k(_ s: String) -> Bool { s.range(of: "4k|2160|uhd", options: [.regularExpression, .caseInsensitive]) != nil }
        func kindMatch(_ path: String) -> Bool {
            path.range(of: item.kind == .series ? "tv|anime|series|show" : "movie|film", options: [.regularExpression, .caseInsensitive]) != nil
        }
        let root = roots.first(where: { kindMatch($0.path) && is4k($0.path) == wants4k })
            ?? roots.first(where: { kindMatch($0.path) }) ?? roots.first(where: { is4k($0.path) == wants4k }) ?? roots.first
        let profileIs4k: (QualityProfile) -> Bool = { $0.name.range(of: "4k|2160|uhd|ultra", options: [.regularExpression, .caseInsensitive]) != nil }
        let profile = (resolvedKind == "anime" ? profiles.first(where: { $0.mediaKind == "anime" && profileIs4k($0) == wants4k }) : nil)
            ?? profiles.first(where: { profileIs4k($0) == wants4k }) ?? profiles.first
        rootId = slot?.rootFolderId ?? root?.id ?? 0
        profileId = slot?.qualityProfileId ?? profile?.id ?? 0
    }

    private func submit() async {
        guard let client = model.client else { return }
        saving = true
        defer { saving = false }
        do {
            try await client.addEdition(itemId: item.id, EditionAddRequest(tier: tier, rootFolderId: rootId, qualityProfileId: profileId,
                                                                           monitored: monitored, searchNow: searchNow))
            onAdded()
        } catch let e as APIError {
            self.error = e.serverDetail ?? (e.status == 409 ? "That edition already exists on this title." : "Couldn't add the edition — try again.")
        } catch {
            self.error = "Couldn't add the edition — try again."
        }
    }
}
