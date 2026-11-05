import SwiftUI
import FusionhaKit

/// The open Duo's right page while no decision is open (mock queue `clear`,
/// inner): Library needs attention, This week (history events per day) and
/// Coming up next.
struct QueueIdleRightPage: View {
    let tasks: IdleSummary.Tasks?
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    @State private var days: [HistorySparklineDay] = []

    var body: some View {
        let attention = V2LibraryAttention.items(model.library)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(attention.isEmpty ? "Nothing needs you" : "Library needs attention")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Text(attention.isEmpty ? "No held downloads, missing files or dead links"
                                       : "From the last health check · \(ActFmt.plural(attention.count, "title"))")
                    .font(.footnote)
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .padding(.top, 3)
                if !attention.isEmpty {
                    V2NeedsAttentionRow(items: attention, held: []) { model.tab = .library }.padding(.top, 14)
                }
                if !days.isEmpty { week.padding(.top, 22) }
                V2QueueUpNextModule(queued: [], tasks: tasks, row: { _ in EmptyView() }).padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task { days = (try? await model.client?.historySparkline(days: 14)) ?? [] }
    }

    /// One bar per day, today in the accent, the rest a lighter accent.
    private var week: some View {
        let peak = max(1, days.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.title3.weight(.semibold)).foregroundStyle(page?.ink ?? Theme.txt)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 2, bottomTrailingRadius: 2,
                                           topTrailingRadius: 4, style: .continuous)
                        .fill(index == days.count - 1 ? Theme.primary : Theme.primary.opacity(0.35))
                        .frame(height: max(3, 92 * CGFloat(day.count) / CGFloat(peak)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92, alignment: .bottom)
            .padding(14)
            .background { ModuleSurface() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("History events per day, peak \(peak)")
            Text("History events per day, last \(days.count) days · peak \(peak)")
                .font(.footnote)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
        }
    }
}
