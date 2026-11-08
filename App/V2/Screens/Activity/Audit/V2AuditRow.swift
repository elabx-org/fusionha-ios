import SwiftUI
import FusionhaKit

/// One change as a row of the Audit module (the History story's anatomy):
/// the poster or a one-ink tile, the title and year with the time, what
/// changed, then who and the kind (a lock when sensitive). Folded, a tap
/// opens the detail lines under it; on the open Duo the row points at the
/// right page (`V2AuditDetail`).
struct V2AuditRow: View {
    let entry: AuditEntry
    let open: Bool
    /// The open Duo: a chevron that points at the right page.
    var points = false
    let tap: () -> Void
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 11) {
                    lead
                    VStack(alignment: .leading, spacing: 2) {
                        titleLine
                        Text(V2AuditCopy.headline(entry))
                            .font(headlineFont)
                            .foregroundStyle(V2AuditCopy.destructive(entry) ? Theme.dangerText : ink)
                            .fixedSize(horizontal: false, vertical: true)
                        V2AuditWhoLine(entry: entry).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if points {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(muted)
                            .padding(.top, 2)
                    }
                }
                if open && !points {
                    V2AuditDetailLines(entry: entry).padding(.leading, 51)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(points ? "Shows the change beside the list" : (open ? "Hides the detail" : "Shows the detail"))
    }

    /// Without a title line the sentence leads, so it takes the weight.
    private var headlineFont: Font {
        entry.titleTarget == nil ? .system(size: 14, weight: .semibold) : .system(size: 13)
    }

    @ViewBuilder
    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let t = entry.titleTarget {
                (Text(t.title).fontWeight(.bold) + Text(verbatim: t.year.map { " \($0)" } ?? "").foregroundColor(muted))
                    .font(.system(size: 15)).foregroundStyle(ink).lineLimit(1)
            } else if let target = V2AuditCopy.target(entry) {
                Text(target).font(.system(size: 12, design: .monospaced)).foregroundStyle(muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(ActFmt.relative(entry.at)).font(.caption.monospacedDigit()).foregroundStyle(muted)
        }
    }

    @ViewBuilder
    private var lead: some View {
        if let t = entry.titleTarget, t.posterUrl != nil {
            V2ScopeThumb(url: t.posterUrl)
        } else {
            V2TaskTile(systemImage: V2AuditCopy.icon(entry), failed: V2AuditCopy.destructive(entry), size: 40)
        }
    }
}

/// Who did it and the kind, one ink; a lock when the change is sensitive.
struct V2AuditWhoLine: View {
    let entry: AuditEntry
    @Environment(\.pagePalette) private var page

    var body: some View {
        let muted = page?.inkMuted ?? Theme.mut
        HStack(spacing: 6) {
            Text(V2AuditCopy.who(entry))
            if let kind = V2AuditCopy.kind(entry) {
                Text(kind)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((page?.ink ?? Theme.txt).opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            if entry.sensitive == true {
                Image(systemName: "lock.fill").font(.system(size: 11)).accessibilityLabel("Sensitive")
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(muted)
        .lineLimit(1)
    }
}

/// The detail lines, the exact time and the address (v1's open row).
struct V2AuditDetailLines: View {
    let entry: AuditEntry
    @Environment(\.pagePalette) private var page

    var body: some View {
        let muted = page?.inkMuted ?? Theme.mut
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array((entry.detail ?? []).enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 13)).foregroundStyle(page?.ink ?? Theme.txt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(ActFmt.dateTime(entry.at)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(muted)
            if let ip = entry.ip {
                Text([ip, entry.userAgent].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !V2AuditCopy.readable(entry) {
                Text(entry.action).font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
            }
        }
        .textSelection(.enabled)
    }
}

/// A change on the open Duo's right page: the title (Open title when it
/// names one), what changed, who, and the detail on one card.
struct V2AuditDetail: View {
    let entry: AuditEntry
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                if let t = entry.titleTarget, t.posterUrl != nil { V2ScopeThumb(url: t.posterUrl, width: 64) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.titleTarget?.title ?? V2AuditCopy.headline(entry))
                        .font(.title3.weight(.bold)).foregroundStyle(page?.ink ?? Theme.txt)
                        .fixedSize(horizontal: false, vertical: true)
                    if entry.titleTarget != nil {
                        Text(entry.verbFull ?? entry.verb ?? "").font(.system(size: 14))
                            .foregroundStyle(page?.ink ?? Theme.txt).fixedSize(horizontal: false, vertical: true)
                    }
                    V2AuditWhoLine(entry: entry)
                }
            }
            if let id = entry.titleTarget?.itemId {
                V2CapsuleButton(title: "Open title", systemImage: "arrow.up.right.square") { model.open(id) }
            }
            V2AuditDetailLines(entry: entry)
                .frame(maxWidth: .infinity, alignment: .leading)
                .v2CardStyle(padding: 14)
        }
    }
}
