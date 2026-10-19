import SwiftUI
import FusionhaKit


/// "Library stats" (LibraryPulse.tsx mobile sheet): the connection line, stat
/// buttons that set the status filter, the health / 4K coverage / on-disk
/// meters, then In progress and Needs attention, and a link to Activity.
struct LibraryStatsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    let pulse: PulseStats
    @Binding var status: LibraryStatus
    /// Close the sheet, then open Settings › Indexers.
    var manageIndexers: () -> Void = {}
    @State private var grown = false
    @State private var feed = StatsSheetFeed.shared
    /// `/health`, read when the sheet opens (the web shares the shell's query).
    @State private var connection: ConnectionLine = .connecting

    private let order: [(LibraryStatus, String)] = [
        (.all, "titles"), (.complete, "complete"), (.downloading, "downloading"),
        (.missing, "missing"), (.upcoming, "upcoming"),
    ]

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Library stats").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    .padding(.trailing, 36)
                connectionLine
                LibraryWrap(spacing: 8) {
                    ForEach(order.indices, id: \.self) { i in
                        statButton(order[i].0, order[i].1)
                    }
                }
                VStack(spacing: 12) {
                    meter("Library health") {
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach([CardStatus.complete, .downloading, .missing, .upcoming], id: \.self) { seg in
                                    StatusSwatch(token: seg.monoToken, shape: Rectangle())
                                        .frame(width: grown && pulse.totalEditions > 0
                                               ? geo.size.width * CGFloat(pulse.counts[seg] ?? 0) / CGFloat(pulse.totalEditions) : 0)
                                }
                            }
                        }
                        .frame(height: 9)
                        .background(Theme.txt.opacity(0.06))
                        .clipShape(Capsule())
                    } value: { "\(pulse.healthPct)%" }
                    meter("4K coverage") {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Theme.grab)
                                .frame(width: grown && pulse.titles > 0 ? geo.size.width * CGFloat(pulse.fourKTitles) / CGFloat(pulse.titles) : 0)
                        }
                        .frame(height: 9)
                        .background(Theme.txt.opacity(0.07), in: Capsule())
                    } value: { "\(pulse.fourKTitles) / \(pulse.titles) titles" }
                    meter("On disk") { Spacer() } value: { Format.bytes(pulse.onDisk) }
                }
                .padding(.top, 16)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                section("In progress") {
                    StatsInProgressList(operations: feed.inProgress) { _ in
                        dismiss()
                        model.tab = .activity
                    }
                }
                section("Needs attention", id: "needs-attention") {
                    StatsAttentionList(indexers: feed.indexers, rows: feed.rows, manageIndexers: {
                        manageIndexers()
                        dismiss()
                    }, openRow: { row in
                        dismiss()
                        if row.kind == .importHeld { model.tab = .activity } else if let id = row.itemId { model.open(id) }
                    }, act: act, dismissRow: dismissRow)
                    .padding(.horizontal, -16)
                }
                Button {
                    dismiss()
                    model.pendingActivityTab = .tasks
                    model.tab = .activity
                } label: {
                    Text("View all activity ›")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.grab)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        #if DEBUG
        .task(id: feed.loaded) {
            guard feed.loaded, ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_STATS"] == "attention" else { return }
            try? await Task.sleep(for: .milliseconds(600))
            proxy.scrollTo("needs-attention", anchor: .top)
        }
        #endif
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mut)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .padding(.top, 14)
            .padding(.trailing, 14)
            .accessibilityLabel("Close")
        }
        .onAppear {
            withAnimation(motion ? Motion.reveal(1.1) : nil) { grown = true }
        }
        .task { await checkHealth() }
        .task {
            while !Task.isCancelled {
                if let client = model.client { await feed.load(client: client, queue: model.queue) }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// `sheetConn`: a dot (green when connected, red when offline, dim while
    /// connecting or unknown) and the four-state label.
    private var connectionLine: some View {
        let dot: Color = connection == .ok ? Theme.done : connection == .offline ? Theme.danger : Theme.dim
        return HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 8, height: 8)
                .shadow(color: connection == .ok || connection == .offline ? dot.opacity(0.8) : .clear, radius: 3)
            Text(connection.label)
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .combine)
    }

    private func checkHealth() async {
        guard let client = model.client else { connection = .unknown; return }
        do {
            let health = try await client.health()
            connection = ConnectionLine(loading: false, failed: false, status: health.status)
        } catch is CancellationError {
            return
        } catch {
            connection = .offline
        }
    }

    /// `.sheetSection`: a hairline, then the 11/700 uppercase label.
    private func section<Content: View>(_ title: String, id: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.22)
                .foregroundStyle(Theme.dim)
            content()
        }
        .padding(.top, 16)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .id(id ?? title)
    }

    private func act(_ row: StatsAttentionRow) {
        dismiss()
        guard let id = row.itemId else { model.tab = .activity; return }
        switch row.action {
        case .manualImport: model.tab = .activity
        case .replace(let tier): model.interactiveSearch(id, tier: tier)
        case .setType: model.edit(id)
        case .review, .view, .seeWhy: model.open(id)
        }
    }

    private func dismissRow(_ row: StatsAttentionRow) {
        guard let client = model.client else { return }
        feed.drop(rowId: row.id)
        Task {
            do {
                if let runId = row.runId {
                    try await client.ackRunAttention(runId)
                } else if let itemId = row.dismissItemId {
                    try await client.dismissScopeMismatch(itemId)
                }
            } catch {
                model.toast(row.runId != nil ? "Couldn't dismiss — the item is back. Try again." : "Couldn't dismiss — try again.",
                            variant: .error)
                await feed.load(client: client, queue: model.queue)
            }
        }
    }

    private func statButton(_ key: LibraryStatus, _ label: String) -> some View {
        let color: Color = key == .all ? Theme.mut : (CardStatus(rawValue: key.rawValue)?.color ?? Theme.i2)
        let count = key == .all ? pulse.titles : (CardStatus(rawValue: key.rawValue).flatMap { pulse.titleCounts[$0] } ?? 0)
        let isActive = status == key
        return Button {
            status = (isActive && key != .all) ? .all : key
            dismiss()
        } label: {
            HStack(spacing: 9) {
                if Theme.isMono, let token = CardStatus(rawValue: key.rawValue)?.monoToken {
                    StatusGlyph(token: token, size: 11).frame(width: 10, height: 10)
                } else if key == .downloading {
                    PulsingDot(color: color, size: 10, period: 1.5)
                } else {
                    Circle().fill(color).frame(width: 10, height: 10)
                        .background(Circle().fill(color.opacity(0.18)).padding(-4))
                }
                Text("\(count)").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            }
            .padding(.leading, 10)
            .padding(.trailing, 13)
            .padding(.vertical, 9)
            .background(isActive ? color.opacity(0.12) : Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.line))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func meter<Bar: View>(_ caption: String, @ViewBuilder bar: () -> Bar, value: () -> String) -> some View {
        HStack(spacing: 12) {
            Text(caption).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
                .frame(minWidth: 96, alignment: .leading)
            bar()
            Text(value()).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Theme.txt)
        }
    }
}
