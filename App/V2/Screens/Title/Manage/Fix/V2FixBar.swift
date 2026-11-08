import SwiftUI
import FusionhaKit

/// One file Pick a release can open the release picker for.
struct V2FixPick: Identifiable {
    let id: Int
    let label: String
    let editionId: Int
    let episodeId: Int?
}

/// What Fix mode's ••• menu reaches.
struct V2FixMenuActions {
    let blocklistAndSearch: () -> Void
    let recheck: () -> Void
    let edit: () -> Void
    let stopMonitoring: () -> Void
    let delete: () -> Void
}

/// Fix mode's glass bar (mock frames 1 and 3): "n selected" when there is a
/// choice, the recommended fix as the accent capsule, then automatic search
/// (keeps the current file) and pick a release when the fix is Replace,
/// and ••• for the rest. Glass on the bar and its controls only.
struct V2FixBar: View {
    let count: Int
    let showsCount: Bool
    let action: ManageFixAction
    let busy: Bool
    let picks: [V2FixPick]
    let primary: () -> Void
    let search: () -> Void
    let pick: (V2FixPick) -> Void
    let menu: V2FixMenuActions

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if showsCount {
                    Text("\(count) selected")
                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.leading, 10)
                }
                primaryButton
                if action == .replace {
                    iconButton("Automatic search", "magnifyingglass", action: search)
                    pickControl
                }
                moreMenu
            }
            .disabled(busy || count == 0)
            .padding(.horizontal, 8)
            .frame(height: 60)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var primaryButton: some View {
        Button(action: primary) {
            HStack(spacing: 7) {
                if busy { ProgressView().tint(Theme.onAccent) } else {
                    Image(systemName: action == .replace ? "arrow.triangle.2.circlepath" : "magnifyingglass")
                }
                Text(ManageFix.primaryLabel(action, count: count))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.primary).interactive(), in: Capsule())
    }

    private func iconButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { iconFace(symbol) }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel(title)
    }

    private func iconFace(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    /// One file opens its picker straight away; several ask which first.
    @ViewBuilder private var pickControl: some View {
        if picks.count == 1, let only = picks.first {
            iconButton("Pick a release", "person") { pick(only) }
        } else if picks.count > 1 {
            Menu {
                pickItems
            } label: { iconFace("person") }
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Pick a release")
        }
    }

    @ViewBuilder private var pickItems: some View {
        Section("Pick a release · one at a time") {
            ForEach(picks) { p in Button(p.label) { pick(p) } }
        }
    }

    private var moreMenu: some View {
        Menu {
            if picks.count == 1, let only = picks.first {
                Button("Pick a release", systemImage: "person") { pick(only) }
            } else if picks.count > 1 {
                Menu("Pick a release", systemImage: "person") { pickItems }
            }
            Button("Blocklist and search", systemImage: "nosign", action: menu.blocklistAndSearch)
            Button("Re-check the files", systemImage: "arrow.clockwise", action: menu.recheck)
            Button("Edit quality or group", systemImage: "pencil", action: menu.edit)
            Divider()
            Button("Stop monitoring", systemImage: "bookmark.slash", role: .destructive, action: menu.stopMonitoring)
            Button("Delete", systemImage: "trash", role: .destructive, action: menu.delete)
        } label: { iconFace("ellipsis") }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("More fixes")
    }
}
