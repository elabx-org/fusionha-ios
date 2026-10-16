import SwiftUI
import FusionhaKit

/// Tasks › Needs attention (web `NeedsAttention` + `EnrichmentGroup`): the
/// files media analysis gave up on, a verdict bar by reason, then one group
/// per reason (largest first, first open) with its fix-all and per-file fixes.
struct EnrichmentAttentionView: View {
    let issues: [EnrichmentIssue]
    let onChanged: () async -> Void
    @State private var open: Set<String> = []
    @State private var seeded = false

    var body: some View {
        let groups = EnrichmentGroup.groups(issues)
        VStack(alignment: .leading, spacing: 10) {
            verdict(groups)
            ForEach(groups) { g in
                EnrichmentGroupCard(group: g, open: open.contains(g.reason), onChanged: onChanged) {
                    if open.contains(g.reason) { open.remove(g.reason) } else { open.insert(g.reason) }
                }
            }
        }
        .onAppear {
            guard !seeded, let first = groups.first else { return }
            seeded = true
            open = [first.reason]
        }
    }

    private func verdict(_ groups: [EnrichmentGroup]) -> some View {
        let total = max(1, issues.count)
        return VStack(alignment: .leading, spacing: 8) {
            (Text("\(issues.count.formatted()) file\(issues.count == 1 ? " needs" : "s need") attention").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text("  grouped by what’s wrong").foregroundColor(Theme.mut))
                .font(.system(size: 13.5))
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(groups) { g in
                        Capsule().fill(Self.color(g.tone))
                            .frame(width: max(4, geo.size.width * Double(g.issues.count) / Double(total) - 2))
                    }
                }
            }
            .frame(height: 6)
            ActFlow(spacing: 12, lineSpacing: 6) {
                ForEach(groups) { g in
                    HStack(spacing: 5) {
                        Circle().fill(Self.color(g.tone)).frame(width: 7, height: 7)
                        Text(g.heading).foregroundStyle(Theme.mut)
                        Text("\(g.issues.count)").fontWeight(.bold).foregroundStyle(Theme.txt)
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func color(_ tone: EnrichmentGroup.Tone) -> Color {
        switch tone {
        case .blocked: return Theme.danger
        case .wrong: return Theme.miss
        case .skip: return Theme.dim
        }
    }
}

/// One reason group: heading, count, qualifier and the fix-all; opens to
/// what's wrong, how to fix it, and each file with its fixes.
private struct EnrichmentGroupCard: View {
    let group: EnrichmentGroup
    let open: Bool
    let onChanged: () async -> Void
    let onToggle: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @State private var confirm: (fix: EnrichmentFix, ids: [Int])?
    @State private var busy = false
    @State private var alsoDisk = false

    private var tone: Color { EnrichmentAttentionView.color(group.tone) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if open {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.whatsWrong).foregroundStyle(Theme.txt)
                    if !group.howToFix.isEmpty { Text(group.howToFix).foregroundStyle(Theme.mut) }
                }
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
                ForEach(group.issues) { issue in row(issue) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .actWash(tone)
        .disabled(busy)
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible) {
            if let c = confirm {
                if c.fix == .forget {
                    Button("Forget record\(c.ids.count == 1 ? "" : "s")", role: .destructive) { run(.forget, c.ids) }
                    Button("Forget and delete from disk", role: .destructive) { alsoDisk = true; run(.forget, c.ids) }
                } else {
                    Button(c.fix.label, role: .destructive) { run(c.fix, c.ids) }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.heading).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text("\(group.issues.count)").font(.system(size: 12, weight: .bold)).foregroundStyle(tone)
                        }
                        if !group.qualifier.isEmpty {
                            Text(group.qualifier).font(.system(size: 12)).foregroundStyle(Theme.mut)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let fix = group.fixAll {
                Button(group.fixAllLabel) {
                    let ids = group.issues.map(\.id)
                    if fix == .retry { run(.retry, ids) } else { confirm = (fix, ids) }
                }
                .buttonStyle(ActButtonStyle(kind: fix == .retry ? .subtle : .warn))
            }
        }
    }

    private func row(_ issue: EnrichmentIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text([issue.title, issue.code].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt).lineLimit(1)
                if let name = issue.fileName {
                    Text(name).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(group.fixes, id: \.self) { fix in
                    Button(fix.label, systemImage: fix.symbol, role: fix == .retry ? nil : .destructive) {
                        if fix == .retry { run(.retry, [issue.id]) } else { confirm = (fix, [issue.id]) }
                    }
                }
                if let item = issue.itemId {
                    Button("Open title", systemImage: "arrow.up.forward") { model.open(item) }
                }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                    .frame(width: 32, height: 32).contentShape(Rectangle())
            }
            .accessibilityLabel("Fixes for \(issue.title)")
        }
        .padding(.top, 4)
    }

    private var confirmTitle: String {
        guard let c = confirm else { return "" }
        let what = c.ids.count == 1 ? "this file" : "\(c.ids.count) files"
        switch c.fix {
        case .replace: return "Replace \(what)? Each is deleted and searched for again."
        case .delete: return "Delete \(what)? The slot is marked missing."
        case .forget: return "Forget \(c.ids.count == 1 ? "this record" : "\(c.ids.count) records")? Only the database row goes, unless you also delete from disk."
        case .retry: return ""
        }
    }

    private func run(_ fix: EnrichmentFix, _ ids: [Int]) {
        let disk = alsoDisk
        alsoDisk = false
        confirm = nil
        Task {
            guard let client = model.client else { return }
            busy = true
            defer { busy = false }
            do {
                switch fix {
                case .retry:
                    let n = try await client.requeueEnrichment(fileIds: ids)
                    toaster.show(n == 0 ? "Those files couldn’t be queued again." : "Queued \(n) for another analysis.", tone: n == 0 ? .warning : .success)
                case .replace:
                    if ids.count == 1 { try await client.replaceFile(fileId: ids[0]) } else { try await client.bulkReplaceFiles(fileIds: ids) }
                    toaster.show("Replaced. Searching for new copies.", tone: .success)
                case .delete:
                    var failed = 0
                    for id in ids { do { try await client.deleteFile(id: id, blocklist: false) } catch { failed += 1 } }
                    toaster.show(failed > 0 ? "Removed \(ids.count - failed); \(failed) couldn’t be removed." : "Removed.", tone: failed > 0 ? .warning : .success)
                case .forget:
                    let r = try await client.forgetUnlinked(fileIds: ids, deleteFromDisk: disk)
                    let skipped = r.skipped?.count ?? 0
                    toaster.show(skipped > 0 ? "Forgot \(r.removed); \(skipped) left alone." : "Forgot \(r.removed).", tone: skipped > 0 ? .warning : .success)
                }
            } catch APIError.http(409, _) {
                toaster.show("Mount not ready or the link recovered, so nothing was deleted.", tone: .warning)
            } catch {
                toaster.show(ErrorCopy.message(for: error, fallback: "That didn’t work. Try again."), tone: .error)
            }
            await onChanged()
        }
    }
}
