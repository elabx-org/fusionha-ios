import SwiftUI
import FusionhaKit

// MARK: - Running rows

struct RunningRow: View {
    let run: ActivityRun
    let queued: Bool
    let playful: Bool
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        let pct = TasksLogic.progressPct(run)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 13) {
                TaskIconTile(color: Theme.grab, spinning: !queued && !reduce) { TaskSpinnerGlyph() }
                VStack(alignment: .leading, spacing: 0) {
                    TaskNameLine(run: run)
                    TaskFactLine(run: run)
                    TaskBar(fraction: queued ? 0 : (pct ?? 1), live: !queued && pct == nil)
                }
            }
            HStack {
                Spacer(minLength: 0)
                Text(ActFmt.relative(run.startedAt))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(TaskCard(border: Theme.grab.opacity(0.3)))
    }
}

/// The live backlog-search card (`SearchRunCard`) with real progress and Stop.
struct SearchRunCard: View {
    let run: ActivityRun
    let onChanged: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false
    @State private var stopping = false

    var body: some View {
        if let search = run.search {
            content(search)
        }
    }

    private func content(_ search: SearchProgress) -> some View {
        let stuck = search.stuck
        let tone = stuck ? Theme.miss : Theme.grab
        let pct = TasksLogic.searchPct(search)
        let isStopping = stopping || search.stopped
        return HStack(alignment: .top, spacing: 12) {
            TaskIconTile(color: tone, spinning: !reduce && !stuck, size: 30, radius: 9, glyph: 15) { TaskSpinnerGlyph() }
            VStack(alignment: .leading, spacing: 0) {
                ActFlow(spacing: 9, lineSpacing: 4) {
                    Text(run.name).font(.system(size: 14.5, weight: .heavy)).foregroundStyle(Theme.txt)
                    Text(stuck ? "⏸ STALLED?" : "● RUNNING")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.4)
                        .foregroundStyle(tone)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tone.opacity(0.16), in: Capsule())
                        .overlay(Capsule().strokeBorder(tone.opacity(0.36)))
                    Text("started \(ActFmt.relative(run.startedAt))")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                Text(TasksLogic.scopeLine(search))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 3)
                ActFlow(spacing: 14, lineSpacing: 4) {
                    count("✓", search.grabbed, "grabbed", Theme.done)
                    count("—", search.noRelease, "no release", Theme.mut)
                    count("●", TasksLogic.searchingCount(search), "searching", Theme.grab)
                    count("○", search.queued, "queued", Theme.dim)
                }
                .padding(.top, 10)
                HStack(spacing: 12) {
                    ActProgressBar(fraction: Double(pct) / 100, height: 7,
                                   fill: stuck ? AnyShapeStyle(LinearGradient(colors: [Theme.miss, Theme.danger.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                                               : AnyShapeStyle(LinearGradient(colors: [Theme.edition.opacity(0.9), Theme.grab], startPoint: .leading, endPoint: .trailing)),
                                   shimmer: !stuck, mono: stuck ? .miss : .grab)
                    Text("\(search.processed) / \(search.total) · \(pct)%")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                        .contentTransition(.numericText(value: Double(search.processed)))
                        .frame(minWidth: 96, alignment: .trailing)
                }
                .padding(.top, 10)
                if stuck {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 13, weight: .semibold))
                        Text("No target has advanced for \(TasksLogic.duration(search.stalledSeconds)) — indexers may be slow or the run is stuck\(search.current.map { " on “\($0)”" } ?? "").")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.miss)
                    .padding(.top, 9)
                } else {
                    HStack(spacing: 9) {
                        Text("Now").fontWeight(.bold).foregroundStyle(Theme.grab)
                        Text(search.current ?? "—").fontWeight(.semibold).foregroundStyle(Theme.txt).lineLimit(1)
                        Spacer(minLength: 0)
                        if let last = search.lastProgressAt {
                            Text("last result \(ActFmt.relative(last))").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
                        }
                    }
                    .font(.system(size: 12.5))
                    .padding(.top, 9)
                }
                HStack(spacing: 12) {
                    if search.total > 0 {
                        Button {
                            if reduce { open.toggle() } else { withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.28)) { open.toggle() } }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).rotationEffect(.degrees(open ? 90 : 0))
                                Text(open ? "Hide targets" : "Show all \(search.total) targets")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    Button {
                        stop()
                    } label: {
                        Text(isStopping ? "Stopping…" : "■ Stop")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.danger.opacity(0.42)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isStopping)
                    .opacity(isStopping ? 0.65 : 1)
                }
                .padding(.top, 12)
                if open {
                    scope(search)
                        .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .actWash(tone, mono: stuck ? .miss : .grab, radius: 11, base: Theme.card, border: tone.opacity(stuck ? 0.34 : 0.24))
    }

    private func count(_ glyph: String, _ value: Int, _ label: String, _ color: Color) -> some View {
        (Text("\(glyph) ") + Text("\(value)").font(.system(size: 12, weight: .heavy, design: .monospaced)) + Text(" \(label)"))
            .font(.system(size: 12))
            .foregroundStyle(color)
    }

    private func scope(_ search: SearchProgress) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(TasksLogic.groupTargets(search.targets)) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(group.group).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
                            if group.tier != nil {
                                let uhd = TasksLogic.isUhd(group.tier)
                                let color = uhd ? QualityTier.uhd.color : QualityTier.hd.color
                                Text(uhd ? "UHD·4K" : "HD·1080p")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.4)))
                            }
                        }
                        ActFlow(spacing: 7, lineSpacing: 7) {
                            ForEach(Array(group.targets.enumerated()), id: \.offset) { _, target in
                                targetPill(target)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 280)
        .padding(.top, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .padding(.top, 13)
    }

    private func targetPill(_ target: SearchScopeTarget) -> some View {
        let (color, dot, glyph): (Color, Color, String) = {
            switch target.state {
            case "grabbed": return (Theme.done, Theme.done, " ✓")
            case "searching": return (Theme.grab, Theme.grab, " ●")
            case "no_release": return (Theme.dim, Theme.dim, " —")
            default: return (Theme.mut, Theme.dim.opacity(0.6), "")
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(target.label + glyph)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.panel2, in: Capsule())
        .overlay(Capsule().strokeBorder(target.state == "grabbed" || target.state == "searching" ? color.opacity(0.36) : Theme.line))
    }

    private func stop() {
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
