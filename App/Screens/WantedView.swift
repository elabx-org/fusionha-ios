import SwiftUI
import FusionhaKit

/// First cut of Wanted: the three counts. The per-title list, search actions and
/// the 4K Available tab follow the plan.
struct WantedView: View {
    @Environment(AppModel.self) private var model
    @State private var counts: WantedCounts?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let counts {
                    row("Missing", counts.missingCount, Theme.miss, "circle.dashed")
                    row("Cutoff unmet", counts.cutoffUnmetCount, Theme.edition, "arrow.up.circle")
                    row("Upcoming", counts.upcomingCount, Theme.unaired, "clock")
                } else if let error {
                    Label(error, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Wanted")
            .refreshable { await load() }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
            .task { await load() }
        }
    }

    private func row(_ title: String, _ value: Int?, _ color: Color, _ symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(color)
            Spacer()
            Text(value.map(String.init) ?? "–").font(.title3.monospacedDigit().weight(.semibold))
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            counts = try await client.wantedCounts()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
