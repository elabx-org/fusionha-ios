import SwiftUI
import FusionhaKit

// MARK: - Views

/// "In progress" (`OperationsList`): live operations, or "Nothing in progress."
struct StatsInProgressList: View {
    let operations: [StatsOperation]
    let open: (StatsOperation) -> Void

    var body: some View {
        if operations.isEmpty {
            StatsEmptyLine(text: "Nothing in progress.")
        } else {
            VStack(spacing: 0) {
                ForEach(operations) { op in
                    Button { open(op) } label: { StatsOperationRow(op: op) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(op.label) — open in Activity")
                }
            }
        }
    }
}

private struct StatsOperationRow: View {
    let op: StatsOperation
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(op.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                if let message = op.message {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if op.status == .running || op.status == .queued {
                    bar.padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(op.status == .queued ? "queued" : op.progress.map { "\($0)%" } ?? StatsSheetLogic.relative(op.timestamp))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        ZStack {
            switch op.status {
            case .running:
                if motion {
                    ProgressView().controlSize(.mini).tint(Theme.grab)
                } else {
                    Circle().fill(Theme.grab).frame(width: 9, height: 9)
                }
            case .queued, .attention:
                Circle().fill(Theme.grab.opacity(0.6)).frame(width: 8, height: 8)
            case .completed:
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
            case .failed:
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(Theme.mut)
        .frame(width: 30, height: 30)
    }

    private var bar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Theme.i1)
                .frame(width: geo.size.width * CGFloat(op.progress ?? 35) / 100)
        }
        .frame(height: 4)
        .background(Theme.panel2, in: Capsule())
        .clipShape(Capsule())
    }
}

/// "Needs attention" (`AttentionList`).
struct StatsAttentionList: View {
    let indexers: [UnavailableIndexer]
    let rows: [StatsAttentionRow]
    let manageIndexers: () -> Void
    let openRow: (StatsAttentionRow) -> Void
    let act: (StatsAttentionRow) -> Void
    let dismissRow: (StatsAttentionRow) -> Void

    @Environment(\.motionEnabled) private var motion
    @State private var indexersOpen = false

    var body: some View {
        if indexers.isEmpty && rows.isEmpty {
            StatsEmptyLine(text: "Nothing needs attention right now.")
        } else {
            VStack(spacing: 0) {
                if !indexers.isEmpty {
                    indexerGroup
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 || !indexers.isEmpty { Rectangle().fill(Theme.line).frame(height: 1) }
                    attentionRow(row)
                }
            }
        }
    }

    private var indexerGroup: some View {
        let tint = Theme.stuck
        return HStack(alignment: .top, spacing: 11) {
            AttentionIcon(symbol: "antenna.radiowaves.left.and.right", tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Button {
                    withAnimation(motion ? .easeOut(duration: 0.2) : nil) { indexersOpen.toggle() }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("\(ActFmt.plural(indexers.count, "indexer")) unavailable")
                                .font(.system(size: 12.5, weight: .heavy)).foregroundStyle(Theme.txt)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(tint)
                                .rotationEffect(.degrees(indexersOpen ? 180 : 0))
                        }
                        Text("Auto-disabled after repeated failures — retrying automatically")
                            .font(.system(size: 11)).foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(indexersOpen ? "expanded" : "collapsed")
                if indexersOpen {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(indexers) { ix in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 9) {
                                    Text(ix.name).font(.system(size: 11.5, weight: .heavy)).foregroundStyle(Theme.txt)
                                    Text(ix.retryHint()).font(.system(size: 11, weight: .heavy).monospacedDigit())
                                        .foregroundStyle(tint)
                                }
                                if let reason = ix.reason {
                                    Text(reason).font(.system(size: 11)).foregroundStyle(Theme.mut)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionPill(label: "Manage", tint: tint, ghost: true, action: manageIndexers)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .statusWash(tint, base: .clear, radius: 0)
    }

    private func attentionRow(_ row: StatsAttentionRow) -> some View {
        let tint = row.kind == .deadLink ? Theme.stuck : Theme.miss
        return HStack(alignment: .top, spacing: 11) {
            AttentionIcon(symbol: symbol(row.kind), tint: tint)
            Button { openRow(row) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(Theme.txt)
                    HStack(spacing: 5) {
                        if let tier = row.tier {
                            chip(StatsSheetLogic.tierRowLabel(tier), color: tier == .uhd ? Theme.grab : Theme.edition)
                        }
                        if let variant = row.variant { chip(variant, color: Theme.mut, fill: Theme.panel2) }
                        chip(row.kindChip, color: Theme.mut)
                    }
                    if !row.reason.isEmpty {
                        Text(row.reason).font(.system(size: 11.5)).foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                ActionPill(label: row.actionLabel, tint: tint, ghost: row.ghost) { act(row) }
                if row.runId != nil || row.dismissItemId != nil {
                    Button { dismissRow(row) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .statusWash(tint, base: .clear, radius: 0)
    }

    private func symbol(_ kind: StatsAttentionRow.Kind) -> String {
        switch kind {
        case .importHeld: return "arrow.down.to.line"
        case .noGrab: return "magnifyingglass"
        case .numbering: return "list.number"
        case .metadataRemoved: return "icloud.slash"
        case .scopeMismatch: return "powerplug"
        case .deadLink, .deadContent: return "link"
        case .notFound, .partial: return "doc.badge.ellipsis"
        }
    }

    private func chip(_ text: String, color: Color, fill: Color = .clear) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(fill, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color == Theme.mut ? Theme.line : color.opacity(0.45)))
    }
}

private struct AttentionIcon: View {
    let symbol: String
    let tint: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.mut)
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }
}

/// `.rowAction` (solid amber) / `.rowActionGhost` (amber outline).
private struct ActionPill: View {
    let label: String
    let tint: Color
    let ghost: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(ghost ? tint : Theme.bg)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(ghost ? Color.clear : tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ghost ? tint.opacity(0.45) : tint))
        }
        .buttonStyle(PressScaleStyle())
    }
}

private struct StatsEmptyLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(26)
    }
}
