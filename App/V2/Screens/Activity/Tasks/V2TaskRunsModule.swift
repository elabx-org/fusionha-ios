import SwiftUI
import FusionhaKit

/// One finished run in the Recent module (mock `recentRuns` row): the task's
/// tile, "Name · 17:34", the facts in one ink (with the playful quip) and a
/// chevron. A run's earlier repeats fold under it ("3 earlier").
struct V2TaskRunRow: View {
    let run: ActivityRun
    var playful = false
    /// Earlier runs folded under this one, and whether they show.
    var earlier = 0
    var showsEarlier = false
    var nestedEarlier = false
    /// The open Duo: the chevron points at the right page.
    var points = false
    let open: () -> Void
    var toggleEarlier: (() -> Void)?
    @Environment(\.pagePalette) private var page

    var body: some View {
        let kind = TasksLogic.iconKind(run)
        VStack(alignment: .leading, spacing: 6) {
            Button(action: open) {
                HStack(spacing: 11) {
                    V2TaskTile(systemImage: taskIcon(kind), failed: kind == .fail, size: 30)
                        .opacity(nestedEarlier ? 0.6 : 1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(V2TaskRunCopy.nameLine(run)).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(page?.ink ?? Theme.txt).lineLimit(1)
                        V2TaskFactLine(run: run, playful: playful)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .opacity(points ? 1 : 0.7)
                }
                .padding(.leading, nestedEarlier ? 14 : 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(points ? "Shows the run beside the list" : "Shows the run and its decision trail")
            if earlier > 0, let toggleEarlier {
                Button(action: toggleEarlier) {
                    Label(showsEarlier ? "Hide earlier runs" : "\(earlier) earlier",
                          systemImage: showsEarlier ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .padding(.leading, 41)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A run's facts in one ink ("412 releases · 37 evaluated · 1 grabbed"), and
/// the playful quip when the voice is on (v1 `TaskFactLine` without its hues).
struct V2TaskFactLine: View {
    let run: ActivityRun
    var playful = false
    var queued = false
    @Environment(\.pagePalette) private var page

    var body: some View {
        let muted = page?.inkMuted ?? Theme.mut
        var text = Text(TasksLogic.factualLine(run))
        if let quip = TaskVoice.quip(run, playful: playful, queued: queued) {
            text = text + Text("  ·  ") + Text(quip).italic()
        }
        return text
            .font(.system(size: 12.5))
            .foregroundStyle(muted)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The Recent module's rows flattened for a lazy stack: each group's
/// latest run, then its earlier runs when unfolded.
enum V2TaskRecentRows {
    struct Entry: Identifiable {
        let run: ActivityRun
        let groupKey: String
        let earlier: Int
        let nested: Bool
        var id: Int { run.id }
    }

    static func entries(_ groups: [TasksLogic.RunGroup], unfolded: Set<String>) -> [Entry] {
        var out: [Entry] = []
        for group in groups {
            out.append(Entry(run: group.latest, groupKey: group.key, earlier: group.older.count, nested: false))
            if unfolded.contains(group.key) {
                out += group.older.map { Entry(run: $0, groupKey: group.key, earlier: 0, nested: true) }
            }
        }
        return out
    }
}
