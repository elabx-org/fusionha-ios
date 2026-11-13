import SwiftUI
import FusionhaKit

// MARK: - Add edition

/// Add a version. Several at once (owner-approved mock 2026-11-13): tick
/// tiers and editions, and every tier × edition pair becomes its own version
/// (one request each, the server takes one at a time). Pairs already on the
/// title are skipped by name. Each tier keeps its own root folder and
/// profile; the folder name, monitoring and Search now are shared.
struct AddEditionSheet: View {
    @Environment(DetailStore.self) var store
    @Environment(AppModel.self) var model: AppModel?
    @Environment(\.dismiss) var dismiss
    let detail: ItemDetail
    let preset: AddEditionPreset

    static let standard = "Standard"

    @State var tiers: Set<QualityTier> = [.hd]
    /// Ticked edition names; Standard is `standard`.
    @State var editions: Set<String> = [AddEditionSheet.standard]
    @State var customOn = false
    @State var customEdition = ""
    @State var presets: [String] = []
    @State var roots: [QualityTier: Int] = [:]
    @State var profileIds: [QualityTier: Int] = [:]
    @State var folderName = ""
    @State var monitor = "all"
    @State var minimumAvailability = "released"
    @State var monitored = true
    @State var searchNow = true
    @State var defaults: [AddDefaultSlot] = []
    @State var busy = false
    @State var error: String?
    @State var fourK: FourKCheck?
    @State var seeded = false

    var isSeries: Bool { detail.isSeries }
    var profiles: [QualityProfile] { DetailVocab.profiles(store.profiles, for: detail) }
    /// Ticked tiers in display order.
    var tierList: [QualityTier] { QualityTier.ordered.filter { tiers.contains($0) } }
    /// Names typed by hand on other titles, offered beside the Settings cuts.
    var usedNames: [String] {
        AddEditionVocabulary.usedNames(in: model?.library ?? [], kind: detail.kind, excluding: presets)
    }

    var plan: AddEditionPlan {
        AddEditionPlan(tiers: tiers, editions: chosenEditions, existing: (store.detail ?? detail).editions)
    }

    /// The ticked editions in menu order, Standard as nil; a ticked Custom…
    /// joins once it has a name.
    var chosenEditions: [String?] {
        var out: [String?] = []
        if editions.contains(Self.standard) { out.append(nil) }
        out += (presets + usedNames).filter { editions.contains($0) }.map { Optional($0) }
        let custom = customEdition.trimmingCharacters(in: .whitespaces)
        if customOn, !custom.isEmpty, !out.contains(where: { $0?.lowercased() == custom.lowercased() }) {
            out.append(custom)
        }
        return out
    }

    private var canSubmit: Bool {
        !busy && !plan.fresh.isEmpty
            && plan.fresh.allSatisfy { roots[$0.tier] != nil && profileIds[$0.tier] != nil }
    }

    private var addTitle: String {
        plan.fresh.count > 1 ? "Add \(plan.fresh.count) versions" : "Add version"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    tiersRow
                    editionsRow
                    if customOn { customRow }
                    willAddRow
                } header: {
                    Text("\(detail.title) · each tier + edition is its own copy, tracked independently")
                        .textCase(nil)
                }

                if tiers.contains(.uhd) {
                    AddEditionFourKPanel(detail: detail, fourK: $fourK)
                }

                Section {
                    locationRows
                    if isSeries {
                        Picker("Monitor level", selection: $monitor) {
                            ForEach(DetailVocab.monitorOptions, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    } else {
                        Picker("Minimum availability", selection: $minimumAvailability) {
                            ForEach(DetailVocab.minimumAvailability, id: \.value) { Text($0.label).tag($0.value) }
                        }
                    }
                    Toggle(isOn: $monitored) {
                        DialogFieldLabel(title: "Monitored", subtitle: "Track each version and grab it independently")
                    }
                    .tint(Theme.indigo)
                    .accessibilityLabel("Monitor versions")
                    Toggle(isOn: $searchNow) {
                        DialogFieldLabel(title: "Search for releases now", subtitle: "Kick off a search as soon as each version is added")
                    }
                    .tint(Theme.indigo)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            // The keyboard goes with a drag down or Done (owner, IMG_8010): on the
            // folded Duo it shortens the column until Close and Add hide in ⋯.
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.bg)
            .navigationTitle("Add a version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarActionButton(title: addTitle, systemImage: "plus", busy: busy) {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheetBackground(Theme.bg)
        .task {
            await loadVocabulary()
            seed()
        }
        // Survives a fold / unfold (data safety): `seeded` keeps seed() from overwriting it.
        .retainsDraft("add.seeded", $seeded)
        .retainsDraft("add.tiers", $tiers)
        .retainsDraft("add.editions", $editions)
        .retainsDraft("add.customOn", $customOn)
        .retainsDraft("add.customEdition", $customEdition)
        .retainsDraft("add.roots", $roots)
        .retainsDraft("add.folderName", $folderName)
        .retainsDraft("add.profileIds", $profileIds)
        .retainsDraft("add.monitor", $monitor)
        .retainsDraft("add.minimumAvailability", $minimumAvailability)
        .retainsDraft("add.monitored", $monitored)
        .retainsDraft("add.searchNow", $searchNow)
        .retainsDraft("add.fourK", $fourK)
    }

    /// One version per new pair, in order; a 409 (added meanwhile) counts
    /// as already there. The sheet stays open on a failure, naming it.
    private func submit() async {
        guard let client = store.client else { return }
        let todo = plan.fresh
        var skipped = plan.skipped.count
        guard !todo.isEmpty else { return }
        busy = true
        error = nil
        defer { busy = false }
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        var added: [AddEditionPair] = []
        var failed: [AddEditionPair] = []
        for pair in todo {
            guard let root = roots[pair.tier], let profile = profileIds[pair.tier] else { failed.append(pair); continue }
            let body = EditionAdd(
                tier: pair.tier, movieEdition: pair.edition, rootFolderId: root, qualityProfileId: profile,
                monitored: monitored, folderName: folder.isEmpty ? nil : folder,
                monitor: isSeries ? monitor : nil, minimumAvailability: isSeries ? nil : minimumAvailability,
                searchNow: searchNow)
            do {
                try await client.addEdition(itemId: detail.id, body)
                added.append(pair)
            } catch APIError.http(let status, _) where status == 409 {
                skipped += 1
            } catch {
                failed.append(pair)
            }
        }
        if !added.isEmpty || skipped > plan.skipped.count { await store.reload() }
        if failed.isEmpty {
            if !added.isEmpty {
                store.show(AddEditionPlan.outcome(added: added, skipped: skipped, searching: searchNow), variant: .success)
            }
            dismiss()
        } else {
            let names = failed.map(\.label).joined(separator: ", ")
            error = added.isEmpty
                ? "Could not add \(names). Please try again."
                : "Added \(added.count), but could not add \(names). Please try again."
        }
    }
}
