import SwiftUI
import FusionhaKit

// MARK: - Attention card (held / stuck)

struct AttentionCard: View {
    let item: QueueItem
    let actions: QueueRowActions
    @Environment(AppModel.self) private var model
    @State private var showWhy = false
    @State private var blocking = false

    /// A proven fake from a named group, for someone who may block groups.
    private var blockableGroup: String? {
        guard HeldCopy.isProvenMislabel(item.heldDetail), let group = item.heldDetail?.releaseGroup,
              model.me?.can("integrations.manage") == true else { return nil }
        return group
    }

    var body: some View {
        let held = item.cockpitState == .held
        HStack(alignment: .top, spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 5) {
                QueueHead(item: item, chip: held ? ("Manual import required", Theme.miss) : ("Needs attention", Theme.danger))
                ReleaseLine(text: item.releaseTitle)
                HStack(alignment: .top, spacing: 6) {
                    if held {
                        ActPulseDot(color: Theme.miss, size: 6, spread: 5, duration: 2).padding(.top, 4)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(Theme.danger)
                    }
                    Text(reason(held))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(held ? Theme.miss : Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    if held, item.heldDetail != nil {
                        Button { showWhy.toggle() } label: {
                            Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Why it was held")
                    }
                }
                if showWhy, let detail = item.heldDetail { HeldWhy(detail: detail) }
                if held {
                    ActFlow(spacing: 0, lineSpacing: 3) {
                        Text("✓ On disk").foregroundStyle(Theme.done)
                        Text(" · \(ActFmt.bytes(item.size)) · 100%")
                        Text(" · " + [item.downloadClient ?? "Unknown client", item.indexer, item.protocolLabel].compactMap { $0 }.joined(separator: " · "))
                        if item.ageSeconds != nil { Text(" · \(item.queuedAgo)") }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mut)
                } else {
                    QueueMetaLine(item: item, showStatus: false)
                }
                HStack {
                    if let group = blockableGroup {
                        Button("Block \(group)…", systemImage: "nosign") { blocking = true }
                            .font(.system(size: 12, weight: .semibold))
                            .buttonStyle(.bordered)
                            .tint(Theme.miss)
                    }
                    Spacer(minLength: 0)
                    QueueActionsView(item: item, actions: actions,
                                     primary: held ? QueuePrimary(icon: "square.and.arrow.down", label: "Manual import", run: actions.manualImport)
                                                   : QueuePrimary(icon: "magnifyingglass", label: "Search", run: actions.search),
                                     stuck: !held, trashLabel: held ? "Reject" : "Remove from queue", offerSearch: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .actWash(QueueLogic.wash(item))
        .onAppear(perform: consumeFocus)
        .onChange(of: model.pendingQueueFocus?.downloadId) { consumeFocus() }
        .sheet(isPresented: $blocking) {
            if let group = blockableGroup {
                BlockReleaseGroupSheet(group: group, mediaItemId: item.mediaItemId, title: item.title,
                                       claimedResolution: item.heldDetail?.claimedResolution)
            }
        }
    }

    /// A held-fake push links here with `block=1`: open the dialog on this row.
    private func consumeFocus() {
        guard let focus = model.pendingQueueFocus, focus.downloadId == item.id else { return }
        model.pendingQueueFocus = nil
        if focus.block, blockableGroup != nil { blocking = true }
    }

    private func reason(_ held: Bool) -> String {
        if held {
            return HeldCopy.headline(item.heldDetail, reason: item.heldReason) ?? "Not an upgrade — manual import required"
        }
        return item.nextStep ?? "No eligible release left — needs attention"
    }
}

/// `HeldWhyDetail`: claimed vs probed quality, what's on disk, the verdict.
struct HeldWhy: View {
    let detail: HeldDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let headline = HeldCopy.headline(detail, reason: nil) {
                Text(headline).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.miss)
                    .padding(.bottom, 2)
            }
            if let claimed = detail.claimedQuality ?? detail.probedQuality {
                if detail.mislabeled == true, let probed = detail.probedQuality {
                    let res = detail.probedResolution.map { " (\($0.w)×\($0.h))" } ?? ""
                    line("Release claimed:", "\(ActFmt.quality(claimed)) mislabeled — actually \(ActFmt.quality(probed))\(res)")
                } else {
                    line("Release claimed:", ActFmt.quality(claimed))
                }
            }
            if let current = detail.currentQuality {
                let extra = [detail.currentGroup, detail.currentCf.map { "CF \($0)" }].compactMap { $0 }.joined(separator: ", ")
                line("On disk:", ActFmt.quality(current) + (extra.isEmpty ? "" : " (\(extra))"))
            }
            if let verdict = detail.verdict {
                line("Verdict:", "not an upgrade (\(HeldCopy.verdictLabel(verdict)))")
            }
        }
        .padding(8)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
    }

    private func line(_ k: String, _ v: String) -> some View {
        (Text(k + " ").foregroundColor(Theme.dim) + Text(v).foregroundColor(Theme.txt))
            .font(.system(size: 11))
    }
}
