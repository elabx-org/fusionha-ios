import SwiftUI
import FusionhaKit

/// The editable triage: the session state, Sources, the bulk bar, "Needs you"
/// pinned above the collapsed "Ready" group (Accept all N), and the commit bar.
struct ImportTriageList: View {
    let model: ImportWorkspaceModel
    let onEdit: (String) -> Void
    let onOverride: (String) -> Void
    let onClose: () -> Void
    @State private var readyOpen = false
    /// The workspace's own width: above 720 it is the web's desktop modal.
    @State private var width: CGFloat = 0
    @Environment(\.settingsMotionOff) private var motionOff

    /// Web `.body` above 720 (`320px 1fr`): the session and Sources as a rail
    /// beside the triage. At 720 and under, Sources is a disclosure in the list.
    private var twoPanes: Bool { PaneRule.isDesktop(Double(width)) }

    var body: some View {
        Group {
            if twoPanes {
                HStack(spacing: 0) {
                    List {
                        stateSection
                        ImportSourcesSection(model: model, rail: true)
                    }
                    .scrollContentBackground(.hidden)
                    .frame(width: 320)
                    Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
                    triageList(withSources: false)
                }
            } else {
                triageList(withSources: true)
            }
        }
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom) { ImportCommitBar(model: model, onClose: onClose) }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var stateSection: some View {
        Section {
            ImportSessionStateLine(model: model)
        }
        .listRowBackground(Theme.card)
    }

    private func triageList(withSources: Bool) -> some View {
        let triage = model.triage
        return List {
            if withSources {
                stateSection
                ImportSourcesSection(model: model)
            }
            if model.isDraft, !model.matched.isEmpty {
                ImportBulkSection(model: model)
            }
            needsYouSection(triage.needsYou)
            if !triage.ready.isEmpty { readySection(triage.ready) }
        }
        .scrollContentBackground(.hidden)
    }

    private func needsYouSection(_ rows: [LibraryImportItem]) -> some View {
        Section {
            if rows.isEmpty {
                Text("Nothing needs your attention — every match is ready.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
            } else {
                rowList(rows)
            }
        } header: {
            groupHeader("Needs you", count: rows.count, tint: rows.isEmpty ? Theme.mut : Theme.miss)
        }
        .listRowBackground(Theme.card)
    }

    private func readySection(_ rows: [LibraryImportItem]) -> some View {
        Section {
            if readyOpen { rowList(rows) }
        } header: {
            HStack {
                Button {
                    SettingsMotion.perform(motionOff) { readyOpen.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(readyOpen ? 90 : 0))
                            .font(.system(size: 11, weight: .semibold))
                        groupHeader("Ready", count: rows.count, tint: Theme.mut)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityValue(readyOpen ? "Expanded" : "Collapsed")
                Spacer()
                if model.isDraft {
                    Button("Accept all \(rows.count)") { model.acceptAllReady() }
                        .buttonStyle(.web())
                        .textCase(nil)
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    private func groupHeader(_ title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            Text("\(count)").font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.mut)
        }
        .textCase(nil)
    }

    private func rowList(_ rows: [LibraryImportItem]) -> some View {
        ForEach(rows) { item in
            ImportTriageRow(item: item,
                            profileName: profileName(item),
                            editable: model.isDraft,
                            bulkSet: model.bulkSetKeys.contains(item.id),
                            onAccept: { model.setAccepted(item, $0) },
                            onOpen: { onEdit(item.id) },
                            onOverride: { onOverride(item.id) })
        }
    }

    private func profileName(_ item: LibraryImportItem) -> String {
        guard let id = LibraryImportRules.resolvedProfile(item, in: model.profiles) else { return "Profile" }
        return model.profiles.first { $0.id == id }?.name ?? "Profile"
    }
}

/// The Sources group: one card per child scan with its progress and Rescan.
struct ImportSourcesSection: View {
    let model: ImportWorkspaceModel
    /// The desktop rail: always open, no disclosure.
    var rail = false
    @State private var open = false
    @Environment(\.settingsMotionOff) private var motionOff

    var body: some View {
        let sources = model.session?.sources ?? []
        Section {
            if open || rail {
                ForEach(sources) { src in
                    ImportSourceRow(source: src, rescanning: model.working, canRescan: model.isDraft) {
                        Task { await model.rescan(scanId: src.scanId) }
                    }
                }
            }
        } header: {
            Button {
                SettingsMotion.perform(motionOff) { open.toggle() }
            } label: {
                HStack(spacing: 6) {
                    if !rail {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(open ? 90 : 0))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("Sources · \(sources.count)").font(.system(size: 15, weight: .semibold))
                    if sources.contains(where: { $0.status == "scanning" && $0.stalled != true }) {
                        ProgressView().controlSize(.mini)
                    }
                }
                .foregroundStyle(Theme.mut)
                .textCase(nil)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!rail)
            .accessibilityValue(rail ? "" : open ? "Expanded" : "Collapsed")
        }
        .listRowBackground(Theme.card)
    }
}

private struct ImportSourceRow: View {
    let source: LibraryImportSource
    let rescanning: Bool
    let canRescan: Bool
    let onRescan: () -> Void

    private var tone: Color {
        if source.status == "failed" { return Theme.danger }
        if source.status == "interrupted" || source.stalled == true { return Theme.miss }
        return Theme.mut
    }

    private var pathLabel: String {
        if let path = source.path, !path.isEmpty { return path }
        if let id = source.rootFolderId { return "Root #\(id)" }
        return "Root #?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                if let tier = source.qualityTier { TierPill(tier: tier) } else { Text("—").foregroundStyle(Theme.dim) }
                Text(pathLabel)
                    .font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.txt)
                    .lineLimit(1).truncationMode(.head)
            }
            if source.status == "scanning", source.stalled != true {
                if let p = LibraryImportRules.sourceProgress(source) {
                    ProgressView(value: p).tint(source.qualityTier?.color ?? Theme.i1)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            HStack {
                Text(LibraryImportRules.sourceLine(source)).font(.system(size: 12)).foregroundStyle(tone)
                Spacer(minLength: 6)
                if canRescan, LibraryImportRules.canRescan(source) {
                    Button("Rescan", systemImage: "arrow.clockwise", action: onRescan)
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.web())
                        .disabled(rescanning)
                        .accessibilityLabel("Rescan \(source.path ?? "")")
                }
            }
        }
        .padding(.vertical, 3)
    }
}
