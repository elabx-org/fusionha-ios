import SwiftUI
import FusionhaKit

/// The queue's pipeline strip (mock `pipe`): Grabbed · Downloading ·
/// Importing · (Held) · Imported · Failed, today's totals from the idle
/// summary around the live counts. Numbers in the label ink; held is the
/// only colour (it needs the owner), downloading the accent. Under it the
/// nine decypharr stages stay one tap away in a disclosure (parity with
/// v1's `PipelineHero`). Solid content on a W1 surface.
struct SixCountPipelineStrip: View {
    let counts: V2QueueCounts
    let today: IdleSummary.Counts?
    let items: [QueueItem]
    /// The phone leaves Held out: Needs you sits right under it.
    var showsHeld = true
    @State private var showsStages = false
    @Environment(\.pagePalette) private var page

    private struct Cell: Identifiable {
        let label: String
        let value: Int?
        let tone: Color?
        var id: String { label }
    }

    private var cells: [Cell] {
        var out = [Cell(label: "Grabbed", value: today?.grabbed, tone: nil),
                   Cell(label: "Downloading", value: counts.downloading, tone: Theme.accentText),
                   Cell(label: "Importing", value: counts.importing, tone: nil)]
        if showsHeld { out.append(Cell(label: "Held", value: counts.held, tone: counts.held > 0 ? Theme.stuckText : nil)) }
        out += [Cell(label: "Imported", value: today?.imported, tone: nil),
                Cell(label: "Failed", value: today.map { $0.failed } ?? counts.failed, tone: nil)]
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(cells) { cell in
                    VStack(spacing: 1) {
                        Text(cell.value.map(String.init) ?? "–")
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(cell.tone ?? page?.ink ?? Theme.txt)
                            .contentTransition(.numericText())
                        Text(cell.label)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            stagesDisclosure
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .background { ModuleSurface() }
    }

    /// The nine decypharr stages with how many jobs sit at each.
    private var stagesDisclosure: some View {
        let model = QueuePipelineModel(items)
        return DisclosureGroup(isExpanded: $showsStages) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 6) {
                ForEach(model.columns) { column in
                    HStack(spacing: 6) {
                        Text("\(column.count)")
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(column.count > 0 ? Theme.accentText : (page?.inkMuted ?? Theme.mut))
                        Text(column.label)
                            .font(.system(size: 12.5))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                            .strikethrough(column.off)
                            .lineLimit(1)
                    }
                    .opacity(column.off ? 0.55 : 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(column.off ? "turned off in decypharr" : "")
                }
            }
            .padding(.top, 6)
            if let failed = model.failed {
                Text(failed).font(.footnote).foregroundStyle(page?.inkMuted ?? Theme.mut).padding(.top, 4)
            }
        } label: {
            Text(model.running ? "decypharr stages · \(model.jobs) in flight" : "decypharr stages")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
        }
        .tint(page?.inkMuted ?? Theme.mut)
    }
}
