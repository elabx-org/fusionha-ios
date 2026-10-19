import SwiftUI
import FusionhaKit

/// The verdict line, its segmented bar and the filter chips (the web's
/// `VerdictStrip`): the counts double as filters. While files are still being
/// measured it says how many; a stalled probe offers Retry.
struct MIVerdictStrip: View {
    let rows: [ManualImportRow]
    @Binding var filter: ManualImportFilter
    let probing: Int
    let stalled: Bool
    let onRetry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let c = ManualImportFilter.counts(rows)
        VStack(alignment: .leading, spacing: 8) {
            line(c)
            bar(c)
            if rows.count > 1 { chips(c) }
        }
    }

    private func line(_ c: [ManualImportFilter: Int]) -> some View {
        let all = c[.all] ?? 0
        let files: Text = Text("\(all)").bold() + Text(all == 1 ? " file · " : " files · ")
        let ready: Text = count(c[.ready], " ready", Theme.done)
        let look: Text = count(c[.attention], " need a look", Theme.miss)
        let none: Text = count(c[.nomatch], " no match", Theme.danger)
        let dot = Text(" · ")
        let text: Text = files + ready + dot + look + dot + none
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { text; probe }
            VStack(alignment: .leading, spacing: 4) { text; probe }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.mut)
    }

    private func count(_ n: Int?, _ label: String, _ color: Color) -> Text {
        (Text("\(n ?? 0)").bold() + Text(label)).foregroundColor(color)
    }

    @ViewBuilder private var probe: some View {
        if probing > 0 && stalled {
            Button("Probing stalled — Retry", systemImage: "arrow.clockwise", action: onRetry)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
        } else if probing > 0 {
            Label("checking \(probing)", systemImage: "waveform.path.ecg")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        }
    }

    /// Solid segments, never a gradient: ready · need a look · no match.
    private func bar(_ c: [ManualImportFilter: Int]) -> some View {
        let parts: [(Int, Color)] = [(c[.ready] ?? 0, Theme.done), (c[.attention] ?? 0, Theme.miss), (c[.nomatch] ?? 0, Theme.danger)]
        let total = max(1, parts.map(\.0).reduce(0, +))
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    if part.0 > 0 {
                        Capsule().fill(part.1).frame(width: max(3, (geo.size.width - 4) * CGFloat(part.0) / CGFloat(total)))
                    }
                }
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private func chips(_ c: [ManualImportFilter: Int]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 6) {
                    ForEach(ManualImportFilter.chips, id: \.self) { key in chip(key, count: c[key] ?? 0) }
                }
                .padding(.vertical, 2)
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    /// Phone layout (web compact): the glyph and the count; All keeps its word.
    private func chip(_ key: ManualImportFilter, count: Int) -> some View {
        let on = filter == key
        return Button { filter = on && key != .all ? .all : key } label: {
            HStack(spacing: 5) {
                if let glyph = glyph(key) {
                    Image(systemName: glyph).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(key))
                } else {
                    Text(key.label)
                }
                Text("\(count)").bold().monospacedDigit()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? Theme.txt : Theme.mut)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl(on: on)
        .accessibilityLabel("\(key.label) \(count)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func glyph(_ key: ManualImportFilter) -> String? {
        switch key {
        case .ready: return "checkmark"
        case .attention: return "exclamationmark.circle"
        case .nomatch: return "questionmark.circle"
        case .diff: return "notequal"
        case .all, .medium: return nil
        }
    }

    private func tint(_ key: ManualImportFilter) -> Color {
        switch key {
        case .ready: return Theme.done
        case .attention, .diff: return Theme.miss
        case .nomatch: return Theme.danger
        case .all, .medium: return Theme.mut
        }
    }
}

/// One banner for every medium match (the web's `MatchBanner`): Review filters
/// to them; Confirm all vouches for each row's own title.
struct MIMatchBanner: View {
    let blocks: [ManualImportBlock]
    @Binding var filter: ManualImportFilter
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        let low = blocks.filter(\.needsConfirm)
        if !low.isEmpty {
            let reviewing = filter == .medium
            HStack(spacing: 8) {
                Image(systemName: "questionmark.diamond").foregroundStyle(Theme.miss)
                (Text("\(low.count) of \(blocks.count)").bold() + Text(" medium"))
                    .font(.system(size: 13)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                Button(reviewing ? "Show all" : "Review") { filter = reviewing ? .all : .medium }
                    .buttonStyle(ActButtonStyle(kind: .ghost))
                ActAsyncButton(label: "Confirm all", systemImage: "checkmark") {
                    await session.confirm(low.flatMap(\.rows))
                    if reviewing { filter = .all }
                    return true
                }
                .disabled(session.bulkBusy || session.working)
            }
            .padding(10)
            .actWash(Theme.miss, mono: .miss, radius: Theme.radius, base: Theme.panel)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Medium matches")
        }
    }
}
