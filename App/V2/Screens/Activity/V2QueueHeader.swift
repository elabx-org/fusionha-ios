import SwiftUI
import FusionhaKit

/// The top of the v2 queue (mock `phoneHead`): the live caption ("5 in the
/// queue · 2 need you · 1 downloading · 1 importing"). The scopes are pinned
/// above the list (`V2ActivityScopes`); the title search is the bar's
/// pull-down field, not a row here.
struct V2QueueHeader: View {
    let counts: V2QueueCounts
    let loaded: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    var body: some View {
        caption
    }

    private var caption: some View {
        Group {
            if !loaded {
                Text(model.queueError == nil ? "Loading…" : "Queue unavailable")
            } else if counts.total == 0 {
                Text("Queue clear").fontWeight(.semibold).foregroundColor(page?.ink ?? Theme.txt)
            } else {
                counts.captionParts.enumerated().reduce(Text("")) { line, entry in
                    let part = styled(entry.element)
                    return entry.offset == 0 ? part : line + Text(" · ") + part
                }
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
        .lineLimit(2)
        .accessibilityLabel(counts.total == 0 ? "Queue clear" : counts.spoken)
    }

    private func styled(_ part: (text: String, tone: V2QueueCounts.Tone)) -> Text {
        switch part.tone {
        case .lead: return Text(part.text).fontWeight(.semibold).foregroundColor(page?.ink ?? Theme.txt)
        case .needsYou: return Text(part.text).fontWeight(.semibold).foregroundColor(Theme.stuckText)
        case .active: return Text(part.text).fontWeight(.semibold).foregroundColor(Theme.accentText)
        case .plain: return Text(part.text)
        }
    }
}

/// Activity's scopes as one row of glass chips (Queue, History, Wanted,
/// Blocklist, Tasks, then Audit and Indexers for those who may see them).
/// The selected chip is the accent glass (selection); the row scrolls and
/// keeps the selected chip in view.
struct V2ActivityScopes: View {
    let queueCount: Int
    @Environment(AppModel.self) private var model
    @Environment(ActChrome.self) private var chrome
    @Environment(\.motionEnabled) private var motion
    /// Whether more chips lie past the leading / trailing edge.
    @State private var fades = [false, true]

    private var tabs: [ActivityTab] {
        var tabs: [ActivityTab] = [.queue, .history, .wanted, .blocklist, .tasks]
        if model.me?.hasPermission("system.admin") == true { tabs.append(.audit) }
        if model.me?.hasPermission("integrations.manage") == true { tabs.append(.indexers) }
        return tabs
    }

    var body: some View {
        ScrollViewReader { proxy in
            row
                .onScrollGeometryChange(for: [Bool].self) { g in
                    [g.contentOffset.x > 1, g.contentOffset.x + g.containerSize.width < g.contentSize.width - 1]
                } action: { _, edges in fades = edges }
                // A soft edge where more chips lie past it: the row reads as
                // one you swipe, never as a chip cut off (owner, 2026-11-19).
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [fades[0] ? .clear : .black, .black],
                                       startPoint: .leading, endPoint: .trailing).frame(width: 16)
                        Rectangle()
                        LinearGradient(colors: [.black, fades[1] ? .clear : .black],
                                       startPoint: .leading, endPoint: .trailing).frame(width: 16)
                    }
                }
                .onChange(of: chrome.tab, initial: true) {
                    withAnimation(motion ? .snappy(duration: 0.3) : nil) { proxy.scrollTo(chrome.tab, anchor: .center) }
                }
        }
    }

    private var row: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(tabs, id: \.self) { chip($0).id($0) }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ tab: ActivityTab) -> some View {
        let on = chrome.tab == tab
        return Button { chrome.tab = tab } label: {
            HStack(spacing: 4) {
                Text(Self.label(tab))
                if tab == .queue, queueCount > 0 {
                    Text("\(queueCount)").font(.system(size: 11.5, weight: .bold).monospacedDigit()).opacity(0.85)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    static func label(_ tab: ActivityTab) -> String {
        switch tab {
        case .queue: return "Queue"
        case .history: return "History"
        case .wanted: return "Wanted"
        case .blocklist: return "Blocklist"
        case .tasks: return "Tasks"
        case .audit: return "Audit"
        case .indexers: return "Indexers"
        }
    }
}
