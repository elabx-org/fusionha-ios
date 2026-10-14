import SwiftUI
import FusionhaKit

// MARK: - Decision trail

struct RunTrail: View {
    let runId: Int
    @Environment(AppModel.self) private var model
    @State private var detail: CommandRunDetail?
    @State private var failed = false
    @State private var rawList = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let detail {
                trail(detail.candidates)
            } else if failed {
                note("The decision trail could not be loaded.")
            } else {
                note("Loading the decision trail…")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .task {
            do { detail = try await model.client?.systemRun(id: runId) } catch { failed = true }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.mut)
    }

    @ViewBuilder
    private func trail(_ candidates: [RunCandidate]) -> some View {
        let grabbed = candidates.filter { $0.action == "GRAB" || $0.action == "UPGRADE" }
        let passed = candidates.filter { $0.action == "REJECT" || $0.action == "SKIP" }
        if grabbed.isEmpty && passed.isEmpty {
            note("No releases were considered on this pass.")
        } else {
            let groups = TasksLogic.groupByReason(passed)
            if rawList {
                trailGroup("Grabbed / Upgraded", grabbed.map { TasksLogic.DedupRow(rep: $0, count: 1, indexers: 1) })
                trailGroup("Passed / Skipped", passed.map { TasksLogic.DedupRow(rep: $0, count: 1, indexers: 1) })
            } else {
                if !groups.isEmpty { VerdictStrip(groups: groups, grabbedCount: grabbed.count, evaluated: passed.count) }
                VStack(alignment: .leading, spacing: 6) {
                    trailLabel("Grabbed / Upgraded")
                    let rows = TasksLogic.dedupe(grabbed)
                    if rows.isEmpty {
                        Text("Nothing grabbed this pass — nothing found beat what you already have.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    } else {
                        ForEach(rows) { row in CandidateLine(row: row) }
                    }
                }
                if !groups.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        trailLabel("Passed / Skipped · grouped by reason")
                        VStack(spacing: 8) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                ReasonGroupView(group: group, defaultOpen: index == 0)
                            }
                        }
                    }
                }
            }
            if !passed.isEmpty {
                (Text("\(ActFmt.plural(passed.count, "release")) → \(ActFmt.plural(groups.count, "reason")). Reposts across indexers are folded (the ×N badge). "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim)
                Button(rawList ? "Show the grouped view" : "Show the raw list") { rawList.toggle() }
                    .font(.system(size: 12))
                    .foregroundStyle(ActColor.segText)
                    .buttonStyle(.plain)
            }
        }
    }

    private func trailLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.5).foregroundStyle(Theme.dim)
    }

    @ViewBuilder
    private func trailGroup(_ label: String, _ rows: [TasksLogic.DedupRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                trailLabel(label)
                ForEach(rows) { row in CandidateLine(row: row) }
            }
        }
    }
}

struct VerdictStrip: View {
    let groups: [TasksLogic.ReasonGroup]
    let grabbedCount: Int
    let evaluated: Int
    @Environment(\.actReduceMotion) private var reduce
    @State private var grown = false

    var body: some View {
        let total = max(groups.reduce(0) { $0 + $1.total }, 1)
        VStack(alignment: .leading, spacing: 11) {
            ActFlow(spacing: 10, lineSpacing: 2) {
                Text(grabbedCount > 0 ? "Why the rest were passed over" : "Why nothing was grabbed")
                    .font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                Text("\(ActFmt.plural(evaluated, "release")), grouped by reason").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(groups) { group in
                        Rectangle().fill(group.bucket.tone.color)
                            .frame(width: max(0, (geo.size.width - CGFloat(groups.count - 1)) * CGFloat(group.total) / CGFloat(total) * (reduce || grown ? 1 : 0)))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.line))
            ActFlow(spacing: 16, lineSpacing: 8) {
                ForEach(groups) { group in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3).fill(group.bucket.tone.color).frame(width: 9, height: 9)
                        (Text(group.bucket.label + " ") + Text("\(group.total)").bold().foregroundColor(Theme.txt))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.mut)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
        .onAppear {
            guard !reduce else { return }
            withAnimation(ActMotion.reveal(0.6)) { grown = true }
        }
    }
}

struct ReasonGroupView: View {
    let group: TasksLogic.ReasonGroup
    @State private var open: Bool
    @Environment(\.actReduceMotion) private var reduce

    init(group: TasksLogic.ReasonGroup, defaultOpen: Bool) {
        self.group = group
        _open = State(initialValue: defaultOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if reduce { open.toggle() } else { withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)) { open.toggle() } }
            } label: {
                HStack(spacing: 12) {
                    Circle().fill(group.bucket.tone.color).frame(width: 10, height: 10)
                    (Text(group.bucket.label).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.txt)
                     + Text(group.qualifier.map { " · \($0)" } ?? "").font(.system(size: 12)).foregroundColor(Theme.mut))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    (Text("\(group.total)").fontWeight(.bold).foregroundColor(Theme.txt) + Text(group.total == 1 ? " release" : " releases"))
                        .font(.system(size: 11.5).monospacedDigit())
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Theme.panel2, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.rows) { row in CandidateLine(row: row) }
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 6)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
    }
}

/// One candidate line (`.tline`): dot, release, group, size, ×N, why.
struct CandidateLine: View {
    let row: TasksLogic.DedupRow

    var body: some View {
        let c = row.rep
        let dot: Color = c.action == "GRAB" ? Theme.done : (c.action == "UPGRADE" ? Theme.grab : (c.action == "REJECT" ? Theme.miss : Theme.dim))
        let whyColor: Color = (c.action == "GRAB" || c.action == "UPGRADE") ? Theme.done : (c.action == "REJECT" ? Theme.miss : Theme.mut)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(c.releaseTitle).foregroundStyle(Theme.txt).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let group = c.releaseGroup { Text(group).foregroundStyle(Theme.edition).lineLimit(1).fixedSize() }
                if let size = c.size { Text(ActFmt.bytes(size)).foregroundStyle(Theme.dim).fixedSize() }
                if row.count > 1 || row.indexers > 1 {
                    Text("×\(row.count)\(row.indexers > 1 ? " · \(row.indexers) indexers" : "")")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.mut)
                        .padding(.horizontal, 7).padding(.vertical, 1)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.line))
                        .fixedSize()
                }
            }
            Text(why(c))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(whyColor)
                .lineLimit(2)
                .padding(.leading, 17)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1).mask(
                HStack(spacing: 3) { ForEach(0..<80, id: \.self) { _ in Rectangle().frame(width: 4) } })
        }
    }

    private func why(_ c: RunCandidate) -> String {
        if let score = c.cfScore, score != 0 {
            let signed = score > 0 ? "+\(score)" : "\(score)"
            return c.reason.isEmpty ? signed : "\(c.reason) · \(signed)"
        }
        return c.reason.isEmpty ? "—" : c.reason
    }
}
