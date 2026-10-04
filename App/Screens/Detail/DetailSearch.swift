import SwiftUI
import FusionhaKit

/// Interactive ("Manual") search: every release the indexers returned for the
/// scope, with its quality, size, age, indexer, seeders, custom-format score and
/// the decision engine's verdict, and a Grab button (a rejected release grabs
/// only as a confirmed override).
struct InteractiveSearchSheet: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.detailReduceMotion) private var reduce
    let target: InteractiveTarget

    private enum SortKey: String, CaseIterable {
        case score = "Score", release = "Release", quality = "Quality", size = "Size", age = "Age", indexer = "Indexer", seed = "Seed"
    }

    @State private var editionId: Int = 0
    @State private var results: [Int: [ReleasePreview]] = [:]
    @State private var failed: Set<Int> = []
    @State private var failureReason: [Int: String] = [:]
    @State private var query = ""
    @State private var resolution = "all"
    @State private var proto = "all"
    @State private var indexer = "all"
    @State private var sort: SortKey = .score
    @State private var descending = true
    @State private var hideRejected = false
    @State private var hideBlocklisted = true
    @State private var grabbing: Set<String> = []
    @State private var grabbed: Set<String> = []
    @State private var override: ReleasePreview?
    @State private var grabSuccess = 0

    private var edition: DetailEdition? { store.detail?.editions.first { $0.id == editionId } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if target.editionIds.count > 1 {
                        Picker("Edition", selection: $editionId) {
                            ForEach(target.editionIds, id: \.self) { id in
                                Text(store.detail?.editions.first { $0.id == id }?.label ?? "Edition").tag(id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Text("Scores come from your custom formats. Rejected releases show why the decision engine passed on them.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dim)
                    content
                }
                .padding(16)
            }
            .background(Theme.bg)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Filter by title…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Manual search").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(target.subtitle).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load(force: true) } } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Search again")
                }
            }
            .alert("Grab a rejected release?", isPresented: Binding(get: { override != nil }, set: { if !$0 { override = nil } }),
                   presenting: override) { release in
                Button("Grab anyway", role: .destructive) { Task { await grab(release, override: true) } }
                Button("Cancel", role: .cancel) {}
            } message: { release in
                Text(release.reason ?? "The decision engine rejected this release.")
            }
        }
        .sensoryFeedback(.success, trigger: grabSuccess)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
        .onAppear { if editionId == 0 { editionId = target.editionIds.first ?? 0 } }
        .task(id: editionId) { await load(force: false) }
    }

    @ViewBuilder
    private var content: some View {
        if failed.contains(editionId) {
            EmptyBox(message: "The indexers couldn't be searched. Try again."
                     + (failureReason[editionId].map { "\n\n\($0)" } ?? ""))
        } else if let releases = results[editionId] {
            let rows = filtered(releases)
            Text("\(rows.count) of \(releases.count) releases")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.mut)
            if rows.isEmpty {
                EmptyBox(message: releases.isEmpty ? "No releases found." : "No releases match these filters.")
            }
            LazyVStack(spacing: 8) {
                ForEach(rows) { release in
                    ReleaseRow(release: release, tier: edition?.tier ?? .hd,
                               busy: grabbing.contains(release.guid), done: grabbed.contains(release.guid)) {
                        if release.rejected { override = release } else { Task { await grab(release, override: false) } }
                    }
                    .transition(.opacity)
                }
            }
        } else {
            HStack(spacing: 10) {
                DetailSpinner(size: 16, color: Theme.grab, period: 0.7)
                Text("Searching indexers…").font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .detailPulse(low: 0.5, high: 1, period: 1.4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private var filterMenu: some View {
        let releases = results[editionId] ?? []
        let indexers = Array(Set(releases.compactMap(\.indexerName))).sorted()
        let protocols = Array(Set(releases.map(\.protocolName).filter { !$0.isEmpty })).sorted()
        return Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Descending", isOn: $descending)
            Picker("Resolution", selection: $resolution) {
                Text("All resolutions").tag("all")
                ForEach(["2160p", "1080p", "720p", "480p"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Protocol", selection: $proto) {
                Text("All protocols").tag("all")
                ForEach(protocols, id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("Indexer", selection: $indexer) {
                Text("All indexers").tag("all")
                ForEach(indexers, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Hide rejected", isOn: $hideRejected)
            Toggle("Hide blocklisted", isOn: $hideBlocklisted)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Sort and filter")
    }

    private func filtered(_ releases: [ReleasePreview]) -> [ReleasePreview] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let rows = releases.filter { r in
            (q.isEmpty || r.title.lowercased().contains(q))
                && (resolution == "all" || DetailText.resolution(r.quality) == resolution)
                && (proto == "all" || r.protocolName == proto)
                && (indexer == "all" || r.indexerName == indexer)
                && !(hideRejected && r.rejected)
                && !(hideBlocklisted && r.blocklisted == true)
        }
        let rank: (ReleasePreview) -> Double = { r in
            switch sort {
            case .score: return Double(r.cfScore ?? 0)
            case .quality: return Double(DetailText.qualityRank.firstIndex(of: r.quality ?? "") ?? -1)
            case .size: return r.size ?? 0
            case .age: return -(r.ageSeconds ?? .greatestFiniteMagnitude)
            case .seed: return Double(r.seeders ?? -1)
            case .release, .indexer: return 0
            }
        }
        return rows.sorted { a, b in
            let less: Bool
            switch sort {
            case .release: less = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .indexer: less = (a.indexerName ?? "") < (b.indexerName ?? "")
            default: less = rank(a) < rank(b)
            }
            return descending ? !less : less
        }
    }

    private func load(force: Bool) async {
        guard let client = store.client, editionId != 0 else { return }
        if !force && results[editionId] != nil { return }
        results[editionId] = nil
        failed.remove(editionId)
        do {
            let releases = try await client.releases(itemId: store.itemId, editionId: editionId,
                                                      episodeId: target.episodeId, seasonNumber: target.seasonNumber)
            if reduce { results[editionId] = releases } else {
                withAnimation(.easeOut(duration: 0.25)) { results[editionId] = releases }
            }
        } catch is CancellationError {
            return
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            failureReason[editionId] = Self.describe(error)
            failed.insert(editionId)
        }
    }

    /// A short, readable cause under the failure message.
    private static func describe(_ error: Error) -> String {
        if let url = error as? URLError {
            return url.code == .timedOut ? "The indexers took too long to answer." : url.localizedDescription
        }
        if case APIError.http(let status, let body) = error {
            let detail = (try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])?["detail"] as? String
            return detail.map { "\($0) (HTTP \(status))" } ?? "The server answered HTTP \(status)."
        }
        if error is DecodingError { return "The server's answer couldn't be read." }
        return error.localizedDescription
    }

    private func grab(_ release: ReleasePreview, override: Bool) async {
        guard let client = store.client else { return }
        grabbing.insert(release.guid)
        defer { grabbing.remove(release.guid) }
        do {
            try await client.grab(itemId: store.itemId, ReleaseGrabRequest(
                release: release, editionId: editionId, episodeId: target.episodeId,
                seasonNumber: target.seasonNumber, override: override))
            grabbed.insert(release.guid)
            grabSuccess += 1
            store.show("Grabbed \(release.title)", variant: .success)
            await store.reload()
        } catch {
            store.show("Couldn't grab \(release.title)", variant: .error)
        }
    }
}

private struct ReleaseRow: View {
    let release: ReleasePreview
    let tier: QualityTier
    let busy: Bool
    let done: Bool
    let grab: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(release.title)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(release.rejected ? Theme.mut : Theme.txt)
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 8, lineSpacing: 6) {
                DetailQualityChip(quality: release.quality, tier: tier)
                if let size = release.size { Text(DetailText.bytes(size)) }
                if let age = release.ageSeconds { Text(ageText(age)) }
                if let name = release.indexerName { Text(name) }
                if release.protocolName.lowercased() == "torrent", let seeders = release.seeders {
                    Label("\(seeders)", systemImage: "arrow.up.circle")
                }
                if let score = release.cfScore {
                    Text("\(score >= 0 ? "+" : "")\(score)")
                        .fontWeight(.bold)
                        .foregroundStyle(score > 0 ? Theme.done : (score < 0 ? Theme.danger : Theme.mut))
                }
                if release.blocklisted == true {
                    Text("blocklisted").foregroundStyle(Theme.danger)
                }
            }
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundStyle(Theme.mut)
            HStack(alignment: .center, spacing: 10) {
                if release.action != "grab" && release.action != "upgrade", let reason = release.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 11.5))
                        .foregroundStyle(release.rejected ? Theme.miss : Theme.mut)
                        .fixedSize(horizontal: false, vertical: true)
                } else if release.action == "upgrade" {
                    Text("Upgrade").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.edition)
                }
                Spacer(minLength: 0)
                Button(action: grab) {
                    HStack(spacing: 6) {
                        if busy { DetailSpinner(size: 12, color: .white) }
                        else { Image(systemName: done ? "checkmark" : "arrow.down.to.line") }
                        Text(done ? "Grabbed" : "Grab")
                    }
                    .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.glassProminent)
                .tint(release.rejected ? Theme.miss : Theme.indigo)
                .disabled(busy || done)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(release.rejected ? Theme.miss.opacity(0.25) : Theme.line))
        .opacity(release.rejected && !done ? 0.85 : 1)
    }

    private func ageText(_ seconds: Double) -> String {
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}
