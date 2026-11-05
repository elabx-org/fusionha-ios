import SwiftUI
import FusionhaKit

/// A live search on v2's Searches tab: v1's `SearchRunCard` facts (name,
/// RUNNING / STALLED?, scope, grabbed / no release / searching / queued, the
/// progress bar, what it's on now, Stop) on the W1 frosted card in the page
/// inks, so it sits on the art ground like the finished runs below it. The
/// per-target list stays on the Activity tab's card.
struct V2LiveSearchRunCard: View {
    let run: ActivityRun
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var inkOverride
    @State private var stopping = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    /// Active work: the accent. Stalled needs the owner: orange.
    private func tone(_ stuck: Bool) -> Color { stuck ? Theme.miss : (inkOverride ?? .page).accent }

    var body: some View {
        if let search = run.search {
            content(search)
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { ModuleSurface(radius: 18) }
        }
    }

    private func content(_ search: SearchProgress) -> some View {
        let stuck = search.stuck
        let pct = TasksLogic.searchPct(search)
        return VStack(alignment: .leading, spacing: 0) {
            head(stuck)
            Text(TasksLogic.scopeLine(search))
                .font(.system(size: 12.5))
                .foregroundStyle(muted)
                .padding(.top, 3)
            ActFlow(spacing: 14, lineSpacing: 4) {
                count(search.grabbed, "grabbed")
                count(search.noRelease, "no release")
                count(TasksLogic.searchingCount(search), "searching")
                count(search.queued, "queued")
            }
            .padding(.top, 8)
            HStack(spacing: 12) {
                ActProgressBar(fraction: Double(pct) / 100, height: 6, fill: AnyShapeStyle(tone(stuck)),
                               shimmer: !stuck, mono: stuck ? .miss : .grab)
                Text("\(search.processed) / \(search.total) · \(pct)%")
                    .font(.system(size: 12.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .contentTransition(.numericText(value: Double(search.processed)))
            }
            .padding(.top, 10)
            HStack(spacing: 12) {
                now(search)
                Spacer(minLength: 0)
                stop(search)
            }
            .padding(.top, 10)
        }
    }

    private func head(_ stuck: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: stuck ? "exclamationmark.triangle" : "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tone(stuck))
            Text(run.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(stuck ? "Stalled?" : "Running")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone(stuck))
            Spacer(minLength: 4)
            Text(ActFmt.relative(run.startedAt))
                .font(.system(size: 12))
                .foregroundStyle(muted)
                .lineLimit(1)
        }
    }

    private func count(_ value: Int, _ label: String) -> some View {
        (Text("\(value)").fontWeight(.semibold).foregroundColor(ink) + Text(" \(label)"))
            .font(.system(size: 12.5))
            .monospacedDigit()
            .foregroundStyle(muted)
    }

    @ViewBuilder
    private func now(_ search: SearchProgress) -> some View {
        if search.stuck {
            Text("No target has advanced for \(TasksLogic.duration(search.stalledSeconds)).")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.miss)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            (Text("Now ").fontWeight(.semibold).foregroundColor(ink) + Text(search.current ?? "—"))
                .font(.system(size: 12.5))
                .foregroundStyle(muted)
                .lineLimit(1)
        }
    }

    private func stop(_ search: SearchProgress) -> some View {
        let isStopping = stopping || search.stopped
        return Button(isStopping ? "Stopping…" : "Stop", systemImage: "stop.fill") { stopRun() }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.danger)
            .buttonStyle(.glass)
            .disabled(isStopping)
    }

    private func stopRun() {
        stopping = true
        Task {
            do {
                try await model.client?.cancelRun(id: run.id)
                onChanged()
            } catch {
                stopping = false
                toaster.error(error)
            }
        }
    }
}
