import SwiftUI
import FusionhaKit

// MARK: - Story row

struct HistoryStoryRow: View {
    let story: HistoryStory
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.paneSize) private var pane
    @State private var blocklistDialog = false
    @State private var regrabConflict = false
    @State private var regrabbing = false
    @State private var blocking = false
    @State private var lifecycle = false

    var body: some View {
        let _ = PerfCount.hit("HistoryStoryRow.body")
        // A solo card with a release name or a failure still discloses it (web `hasSoloDisclosure`).
        let multi = story.events.count > 1 || story.failReason != nil || story.releaseTitle != nil
        ZStack(alignment: .topLeading) {
            if multi {
                ActGroupCard(wash: story.type.wash, base: Theme.card, defaultOpen: false) {
                    ActPoster(url: story.posterUrl, title: story.title, size: .md)
                } title: { lines } trailing: { trailing } content: { HistoryStoryDisclosure(story: story) }
            } else {
                Group {
                    if pane.isDesktopPane {
                        // Desktop: the trailing cluster stays beside the title (web `.chead`).
                        HStack(alignment: .top, spacing: 11) {
                            ActPoster(url: story.posterUrl, title: story.title, size: .md)
                            lines.frame(maxWidth: .infinity, alignment: .leading)
                            trailing.fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 11) {
                                ActPoster(url: story.posterUrl, title: story.title, size: .md)
                                lines.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack(spacing: 10) { Spacer(minLength: 0); trailing }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .actWash(story.type.wash)
            }
            // Timeline node.
            Circle()
                .fill(Theme.bg)
                .overlay(Circle().fill(story.type.color.opacity(0.24)))
                .overlay(Image(systemName: story.type.icon).font(.system(size: 11, weight: .bold)).foregroundStyle(story.type.color))
                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2))
                .frame(width: 22, height: 22)
                .offset(x: -26, y: 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { if let id = story.mediaItemId { model.open(id) } }
        .sheet(isPresented: $lifecycle) { HistoryLifecycleSheet(story: story, onChanged: onChanged) }
        .sheet(isPresented: $blocklistDialog) {
            BlocklistReleaseDialog(release: story.releaseTitle ?? story.title,
                                   keepsCurrentFile: story.actionEntry.blocklistTarget?.keepsCurrentFile == true) { search, deleteFile in
                blocklistDialog = false
                Task { await blocklist(search: search, deleteFile: deleteFile, undo: false) }
            } onCancel: { blocklistDialog = false }
        }
        .sheet(isPresented: $regrabConflict) {
            ActDialog(title: "Re-grab a blocklisted release?",
                      message: "\(story.releaseTitle ?? story.title) is blocklisted for this version. Re-grab it anyway? This clears the block first.",
                      confirmLabel: "Re-grab anyway", confirmKind: .primary, busy: regrabbing,
                      onCancel: { regrabConflict = false },
                      onConfirm: { Task { await regrab(override: true) } }) { EmptyView() }
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActFlow(spacing: 6, lineSpacing: 4) {
                Text(story.type.label).font(.system(size: 14, weight: .bold)).foregroundStyle(story.type.color)
                Text(story.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                if let ep = story.episodeLabel {
                    Text(ep).font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if let tier = story.tier { ActTierChip(tier: tier, big: true, edition: story.edition) }
                if let trigger = story.actionEntry.grabTrigger { ActProvenance(trigger: trigger) }
            }
            line2
            chipRow
        }
    }

    @ViewBuilder
    private var line2: some View {
        ActFlow(spacing: 6, lineSpacing: 4) {
            if story.type == .upgraded, let old = story.oldQuality, let new = story.newQuality {
                Text(ActFmt.quality(old)).strikethrough().font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                Text("→").font(.system(size: 11)).foregroundStyle(Theme.dim)
                Text(ActFmt.quality(new)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.edition.opacity(0.6)))
            } else if let q = story.newQuality ?? story.oldQuality {
                Text(ActFmt.quality(q) + (story.newSize.map { " · \(ActFmt.bytes($0))" } ?? ""))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
            }
            if let cf = HistoryLogic.cfText(story.newCf, story.type == .upgraded ? story.oldCf : nil) {
                Text(cf).font(.system(size: 11.5, weight: .bold, design: .monospaced)).foregroundStyle(Theme.done)
            }
            if let client = story.downloadClient {
                Text("· \(client)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
            }
        }
        if story.type == .failed {
            if let reason = story.failReason ?? story.actionEntry.data?.text("reason") {
                let fail = FailureCopy.format(reason, context: .download)
                Text("\(fail.title) — \(fail.detail)").font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                    .lineLimit(2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var chipRow: some View {
        let order = ["group", "edition", "source", "range", "audio", "size"]
        let sorted = story.chips.sorted { (order.firstIndex(of: $0.kind) ?? 99) < (order.firstIndex(of: $1.kind) ?? 99) }
        return ActFlow(spacing: 5, lineSpacing: 5) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { _, chip in
                ActMonoChip(text: chip.label, color: chipColor(chip), border: chip.kind == "group" ? Theme.indigo.opacity(0.5) : Theme.line)
            }
            if let indexer = story.indexer {
                ActMonoChip(text: indexer, color: Theme.grab, icon: "server.rack")
            }
            if let proto = ActFmt.protocolLabel(story.actionEntry.protocol) {
                ActMonoChip(text: proto, color: Theme.mut, icon: proto == "Torrent" ? "arrow.triangle.branch" : "cloud")
            }
        }
    }

    private func chipColor(_ chip: HistoryChip) -> Color {
        switch chip.kind {
        case "group": return Theme.txt
        case "range": return Theme.onair
        case "audio": return chip.label.lowercased().contains("atmos") || chip.label.lowercased().contains("dts-x") ? Theme.edition : Theme.mut
        default: return Theme.mut
        }
    }

    private var trailing: some View {
        let actions = story.type.actions
        let entry = story.actionEntry
        let hasGrab = story.events.contains { $0.eventType == "GRABBED" }
        return HStack(spacing: 2) {
            // "N events" only on desktop; a phone keeps the time (the disclosure lists them).
            if pane.isDesktopPane && story.events.count > 1 {
                Text("\(story.events.count) events").font(.system(size: 12)).foregroundStyle(Theme.dim).padding(.trailing, 6)
            }
            Text(ActFmt.relative(story.time)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim).padding(.trailing, 6)
            if story.mediaItemId != nil {
                ActIconButton(systemImage: "point.topleft.down.to.point.bottomright.curvepath", label: "Lifecycle") { lifecycle = true }
            }
            if hasGrab {
                ActIconButton(systemImage: "arrow.clockwise", label: "Re-grab this release", busy: regrabbing) {
                    Task { await regrab(override: false) }
                }
            }
            if actions.blocklist {
                // The split button: quick blocklist + search (with Undo), caret opens the dialog.
                // A row with no release keeps it visible but disabled (web `BlocklistReleaseAction`).
                let target = entry.blocklistTarget
                HStack(spacing: 0) {
                    ActIconButton(systemImage: "nosign", label: "Blocklist this release", busy: blocking) {
                        Task { await blocklist(search: true, deleteFile: false, undo: true) }
                    }
                    .padding(.trailing, -10)
                    Button { blocklistDialog = true } label: {
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                            .frame(width: 18, height: 40).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Blocklist options")
                }
                .disabled(target == nil)
                .opacity(target == nil ? 0.4 : 1)
                .accessibilityHint(target == nil ? "This event carries no release to blocklist" : "")
            }
            if let id = story.mediaItemId {
                if actions.open {
                    ActIconButton(systemImage: "arrow.up.right.square", label: "Open in library") { model.open(id) }
                } else if actions.search {
                    ActIconButton(systemImage: "magnifyingglass", label: "Search again", tint: Theme.indigo) { searchAgain() }
                }
            }
            ActMoreMenu {
                if let id = story.mediaItemId {
                    if actions.open {
                        Button("Search again", systemImage: "magnifyingglass") { searchAgain() }
                    } else if actions.search {
                        Button("Open in library", systemImage: "arrow.up.right.square") { model.open(id) }
                    }
                    Button("Why this decision", systemImage: "list.bullet") { model.open(id, tab: .searches) }
                }
                if let release = story.releaseTitle {
                    Button("Copy release name", systemImage: "doc.on.doc") { ActActions.copy(release, toaster) }
                }
            }
            .padding(.horizontal, -6)
        }
    }

    // MARK: Actions

    private func searchAgain() {
        guard let id = story.mediaItemId else { return }
        // The story's own episode, so an episode's failure doesn't search the whole edition.
        Task { await ActActions.search(model.client, toaster, itemId: id, editionId: story.actionEntry.editionId,
                                       episodeId: story.actionEntry.episodeId,
                                       message: "Searching again for \(story.title)") }
    }

    private func blocklist(search: Bool, deleteFile: Bool, undo: Bool) async {
        guard let target = story.actionEntry.blocklistTarget else { return }
        blocking = true
        await ActActions.blocklist(model.client, toaster, target.body(search: search, deleteFile: deleteFile),
                                   offerUndo: undo, done: onChanged)
        blocking = false
    }

    private func regrab(override: Bool) async {
        guard let client = model.client else { return }
        regrabbing = true
        defer { regrabbing = false }
        do {
            let r = try await client.regrab(historyId: story.actionEntry.id, override: override)
            regrabConflict = false
            if r.grabbed {
                let indexer = r.indexerName ?? "the indexer"
                toaster.show(r.fromOriginalIndexer == false ? "Grabbed from \(indexer) (original unavailable)" : "Re-grabbed from \(indexer)",
                             tone: .success)
                onChanged()
            } else {
                toaster.show(r.reason ?? "Nothing to re-grab", tone: .warning)
            }
        } catch let error as APIError where error.status == 409 && !override {
            regrabConflict = true
        } catch let error as APIError where error.status == 422 || error.status == 404 {
            toaster.show(error.serverDetail ?? "Couldn't re-grab this release — try again", tone: .warning)
        } catch {
            toaster.show("Couldn't re-grab this release — try again", tone: .error)
        }
    }
}

