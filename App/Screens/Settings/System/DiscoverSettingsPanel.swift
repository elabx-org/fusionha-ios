import SwiftUI
import WebKit
import FusionhaKit

// MARK: Discover

/// Ignored collections and films (the web's `IgnoredPanel.tsx`), each with
/// Un-ignore (`DELETE /api/v1/discover/ignores/{id}`).
struct DiscoverSettingsPanel: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var rows: [JSONRecord]?
    @State private var error: String?
    @State private var busy: Set<Int> = []

    var body: some View {
        SettingsForm(slug: "discover") {
            Section {
                Text("Anything you’ve **ignored** on Discover lives here — whole collections hidden from the “Complete your collections” rail, and single films hidden within a collection. Ignoring is a reversible hide, never a delete: un-ignore to bring it straight back.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mut)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))

            if let error {
                SettingsLoadingRow(error: "Couldn’t load your ignored items. Check the backend and try again. (\(error))")
            } else if let rows {
                if rows.isEmpty {
                    Section {
                        Text("Nothing ignored. Ignore a collection or a film from Discover and it’ll show up here to restore.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.mut)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }
                    .listRowBackground(Color.clear)
                } else {
                    let collections = rows.filter { $0["scope"]?.string == "collection" }
                    let items = rows.filter { $0["scope"]?.string == "item" }
                    group("Ignored collections", sub: "\(collections.count) hidden from the rail", collections)
                    group("Ignored films", sub: "\(items.count) hidden within a collection", items)
                }
            } else {
                SettingsLoadingRow()
            }
        }
        .task { await load() }
    }

    private func group(_ title: String, sub: String, _ list: [JSONRecord]) -> some View {
        Section {
            if list.isEmpty {
                Text("None.").font(.system(size: 13)).foregroundStyle(Theme.dim)
            }
            ForEach(list) { row in
                HStack {
                    Text(label(row))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                    Spacer()
                    Button("Un-ignore") { Task { await restore(row) } }
                        .buttonStyle(.web())
                        .disabled(busy.contains(row.id))
                }
                .transition(motionOff ? .identity : .opacity.combined(with: .move(edge: .trailing)))
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 12.5, weight: .bold)).textCase(nil).foregroundStyle(Theme.mut)
                Spacer()
                Text(sub).font(.system(size: 11.5)).textCase(nil).foregroundStyle(Theme.dim)
            }
        }
        .listRowBackground(Theme.card)
    }

    private func label(_ row: JSONRecord) -> String {
        let name = row["name"]?.string ?? ""
        if row["scope"]?.string == "item", let collection = row["collection_name"]?.string {
            return "\(name) — in \(collection)"
        }
        return name
    }

    private func load() async {
        guard let client = store.client else { return }
        do {
            rows = try await client.records("/api/v1/discover/ignores")
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore(_ row: JSONRecord) async {
        guard let client = store.client else { return }
        busy.insert(row.id)
        defer { busy.remove(row.id) }
        do {
            try await client.json("DELETE", "/api/v1/discover/ignores/\(row.id)")
            SettingsMotion.perform(motionOff) { rows?.removeAll { $0.id == row.id } }
        } catch {
            store.saveError = "Couldn’t restore \(row["name"]?.string ?? "it"): \(error.localizedDescription)"
        }
    }
}
