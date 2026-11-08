import SwiftUI
import FusionhaKit

/// v2's Activity › Audit (plan S10, built like History on the tint ground).
/// v1's calls and filters (`V2AuditModel`); v2's look: the server-counted
/// categories as glass chips, Who, Since and Sensitive as glass menus, then
/// every change as one W1 module (newest first, Load older). Folded, a row
/// opens its detail in place; on the open Duo the picked change fills the
/// right page (`V2AuditDetail`).
struct V2AuditScope: View {
    let search: String
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var data = V2AuditModel()
    /// The row open: in place when folded, on the right page when split.
    @State private var open: Int?

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }

    var body: some View {
        @Bindable var chrome = chrome
        V2ScopeColumns(split: split) {
            V2ScopeList(gutter: split.gutter) {
                V2ScopeCaption(lead: captionLead, rest: captionRest)
            } content: { content }
        } right: {
            V2RightPage {
                if let entry = picked {
                    V2AuditDetail(entry: entry).id(entry.id)
                } else if data.loaded {
                    Text("Pick a change to see who made it, from where, and what it touched.")
                        .font(.system(size: 14)).foregroundStyle(Theme.mut).padding(.top, 40)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .v2PageGround(art: nil)
        .searchable(text: $chrome.searchInput, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search titles")
        .animation(motion ? ActMotion.rows : nil, value: data.items.map(\.id))
        .task(id: data.reloadKey(search: search)) { await data.reload(model.client, search: search) }
        .task { await data.loadActors(model.client) }
    }

    private var captionLead: String {
        guard data.loaded else { return "Loading…" }
        return ActFmt.plural(data.counts?.all ?? data.items.count, "change")
    }

    private var captionRest: [String] {
        var out = ["newest first"]
        if let omitted = data.counts?.omittedLookups, omitted > 0 {
            out.append("\(omitted.formatted()) lookups no longer recorded")
        }
        return out
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var data = data
        V2GlassChips(options: categoryChips, selection: $data.filter.category).v2ScopeBlock()
        V2AuditFilters(data: data).v2ScopeBlock(14)
        if !data.loaded {
            ProgressView("Loading the audit log…").frame(maxWidth: .infinity).padding(.top, 40)
        } else if data.failed && data.items.isEmpty {
            ContentUnavailableView("The audit log could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else if data.items.isEmpty {
            if data.unfiltered && search.isEmpty {
                ContentUnavailableView("No changes recorded yet", systemImage: "list.bullet.rectangle",
                                       description: Text("Every change made through Fusionha shows up here."))
            } else if !search.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ContentUnavailableView("Nothing matches these filters", systemImage: "line.3.horizontal.decrease")
            }
        } else {
            rows
        }
    }

    @ViewBuilder
    private var rows: some View {
        let items = data.items
        ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
            V2AuditRow(entry: entry, open: open == entry.id, points: split.splits) { tap(entry) }
                .v2ModuleRow(index, of: items.count, selected: split.splits && entry.id == picked?.id)
        }
        footer
    }

    private var footer: some View {
        Group {
            if data.loadingMore {
                ProgressView().controlSize(.small)
            } else if data.hasMore {
                V2CapsuleButton(title: "Load older", systemImage: "arrow.down") {
                    Task { await data.loadOlder(model.client, search: search) }
                }
            } else {
                Text("You’ve reached the end · \(data.items.count.formatted()) loaded")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var categoryChips: [V2GlassChips<String?>.Option] {
        var out: [V2GlassChips<String?>.Option] = [.init(value: nil, label: "All", count: data.counts?.all)]
        for category in AuditFilter.categories {
            out.append(.init(value: category.key, label: category.label, count: data.counts?.count(category.key)))
        }
        return out
    }

    /// The open Duo's change: the one picked, else the newest.
    private var picked: AuditEntry? {
        guard split.splits else { return nil }
        return data.items.first { $0.id == open } ?? data.items.first
    }

    private func tap(_ entry: AuditEntry) {
        withAnimation(motion ? .snappy(duration: 0.25) : nil) {
            if split.splits {
                open = entry.id
            } else {
                open = open == entry.id ? nil : entry.id
            }
        }
    }
}

/// Who, Since and Sensitive as glass controls (v1's filter row).
struct V2AuditFilters: View {
    @Bindable var data: V2AuditModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Button("Everyone") { data.filter.who = nil }
                    ForEach(data.actors) { actor in
                        Button("\(actor.label) · \(actor.count.formatted())") { data.filter.who = actor.key }
                    }
                } label: {
                    GlassMenuLabel(title: data.whoLabel ?? "Who", on: data.filter.who != nil)
                }
                Menu {
                    ForEach(V2AuditModel.windows, id: \.key) { window in
                        Button(window.label) { data.filter.since = window.key }
                    }
                } label: {
                    GlassMenuLabel(title: data.windowLabel ?? "Since", on: data.filter.since != "all")
                }
                sensitive
                Spacer(minLength: 0)
            }
        }
    }

    private var sensitive: some View {
        let on = data.filter.sensitive
        return Button {
            data.filter.sensitive.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: on ? "lock.fill" : "lock")
                Text("Sensitive")
                if let n = data.counts?.sensitive { Text(n.formatted()).monospacedDigit().opacity(0.8) }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
