import SwiftUI
import FusionhaKit

/// The offer-only limits of the Add / Edit connection sheet (web
/// `ConnectionLimitsPicker`): Everything or Only selected, then the profile
/// and root checklists with a default each.
struct ConnectionLimitsSection: View {
    @Binding var onlySelected: Bool
    let profileRows: [(Int, String)]
    let rootRows: [(Int, String)]
    @Binding var profileIds: [Int]
    @Binding var rootIds: [Int]
    @Binding var defaultProfileId: Int?
    @Binding var defaultRootId: Int?

    var valid: Bool { Self.valid(onlySelected: onlySelected, profileIds: profileIds, rootIds: rootIds) }

    static func valid(onlySelected: Bool, profileIds: [Int], rootIds: [Int]) -> Bool {
        !onlySelected || (!profileIds.isEmpty && !rootIds.isEmpty)
    }

    private var footnote: (String, Bool) {
        if !onlySelected { return ("Offering everything (unrestricted)", false) }
        if profileIds.isEmpty || rootIds.isEmpty { return ("Select at least one profile and one root", true) }
        return ("Offering \(profileIds.count) profile\(profileIds.count == 1 ? "" : "s") · \(rootIds.count) root\(rootIds.count == 1 ? "" : "s")", false)
    }

    var body: some View {
        Section {
            Picker("Offered to Overseerr", selection: $onlySelected) {
                Text("Everything").tag(false)
                Text("Only selected").tag(true)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Offered to Overseerr")
        } footer: {
            Text(footnote.0).foregroundStyle(footnote.1 ? Theme.miss : Theme.mut)
        }
        if onlySelected {
            limitSection("Quality profiles", rows: profileRows, selected: $profileIds, defaultId: $defaultProfileId)
            limitSection("Root folders", rows: rootRows, selected: $rootIds, defaultId: $defaultRootId)
        }
    }

    private func limitSection(_ title: String, rows: [(Int, String)], selected: Binding<[Int]>,
                              defaultId: Binding<Int?>) -> some View {
        let effective = Self.effectiveDefault(rows: rows, selected: selected.wrappedValue, current: defaultId.wrappedValue)
        return SettingsSection("\(title) · \(selected.wrappedValue.count) / \(rows.count)") {
            HStack {
                Button("Select all") { selected.wrappedValue = rows.map(\.0) }.buttonStyle(.web(.ghost))
                Button("Clear") { selected.wrappedValue = [] }.buttonStyle(.web(.ghost))
                Spacer()
            }
            ForEach(rows, id: \.0) { id, label in
                let isOn = selected.wrappedValue.contains(id)
                HStack(spacing: 10) {
                    Button {
                        if isOn { selected.wrappedValue.removeAll { $0 == id } } else { selected.wrappedValue.append(id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isOn ? Theme.i2 : Theme.dim)
                            Text(label).font(.system(size: 13.5)).foregroundStyle(Theme.txt).lineLimit(1)
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if isOn {
                        if effective == id {
                            FetchPill(text: "Default", tone: .ok)
                        } else {
                            Button("Make default") { defaultId.wrappedValue = id }
                                .font(.system(size: 11, weight: .semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
        }
    }

    /// The current default when still selected, else the first selected row.
    static func effectiveDefault(rows: [(Int, String)], selected: [Int], current: Int?) -> Int? {
        if selected.isEmpty { return nil }
        if let current, selected.contains(current) { return current }
        return rows.first { selected.contains($0.0) }?.0 ?? selected.first
    }

    /// The offer-limit fields of a write; `fallback` keeps an edited row's
    /// current defaults when it goes back to Everything.
    static func payload(onlySelected: Bool, profileRows: [(Int, String)], rootRows: [(Int, String)],
                        profileIds: [Int], rootIds: [Int], defaultProfileId: Int?, defaultRootId: Int?,
                        fallback: (profile: Int?, root: Int?)) -> [String: SettingsJSON] {
        if onlySelected {
            return [
                "allowed_quality_profile_ids": .ints(profileIds),
                "allowed_root_folder_ids": .ints(rootIds),
                "default_quality_profile_id": .optional(effectiveDefault(rows: profileRows, selected: profileIds, current: defaultProfileId)),
                "default_root_folder_id": .optional(effectiveDefault(rows: rootRows, selected: rootIds, current: defaultRootId)),
            ]
        }
        return [
            "allowed_quality_profile_ids": .null,
            "allowed_root_folder_ids": .null,
            "default_quality_profile_id": .optional(fallback.profile),
            "default_root_folder_id": .optional(fallback.root),
        ]
    }
}
