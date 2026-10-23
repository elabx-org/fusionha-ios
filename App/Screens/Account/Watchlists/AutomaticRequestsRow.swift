import SwiftUI
import FusionhaKit

/// Account's "Automatic requests" (web `AutomaticRequestsCard`, fusionha
/// 0.4.226): one native row, "9 requested this week · 1 needs review" (the
/// review part amber) or "Set up", that opens Watchlists & lists.
struct AutomaticRequestsRow: View {
    let store: WatchlistsStore
    let open: () -> Void

    var body: some View {
        Section {
            Button(action: open) {
                HStack(spacing: 12) {
                    WatchlistMarkGlyph(mark: .list, size: 18)
                        .foregroundStyle(Theme.mut)
                        .frame(width: 30, height: 30)
                        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AutomaticRequestsCopy.rowTitle).font(.body.weight(.semibold)).foregroundStyle(Theme.txt)
                        line.font(.footnote)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(AutomaticRequestsCopy.title)
        }
        .listRowBackground(AccountStyle.cell)
    }

    @ViewBuilder
    private var line: some View {
        if let summary = store.summary {
            let row = AutomaticRequestsCopy.rowLine(summary)
            if let review = row.review {
                Text(row.text).foregroundStyle(Theme.mut) + Text(" · ").foregroundStyle(Theme.mut)
                    + Text(review).fontWeight(.semibold).foregroundStyle(Theme.missText)
            } else {
                Text(row.text).foregroundStyle(row.kind == .fresh ? Theme.accentText : Theme.mut)
                    .contentTransition(.numericText())
            }
        } else if store.summaryFailed {
            Text(AutomaticRequestsCopy.rowFailed).foregroundStyle(Theme.mut)
        } else {
            Text(AutomaticRequestsCopy.loading).foregroundStyle(Theme.dim)
        }
    }
}

/// The web's `.sec` heading (11 pt, uppercase, `--dim`, a hairline after it)
/// as a bare list row.
struct AccountSectionHeading: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.dim)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.top, 14)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
        .listRowSeparator(.hidden)
    }
}

extension View {
    /// Loads Automatic requests and, while a source is mid-pass, re-reads it
    /// every 2 s (web `syncPollMs`); the loop ends once all are idle and
    /// restarts when one runs again.
    func automaticRequestsLoading(_ store: WatchlistsStore, client: APIClient?) -> some View {
        task { await store.load(client) }
            .task(id: store.anyRunning) {
                while store.anyRunning {
                    try? await Task.sleep(for: .seconds(SyncProgress.runningPollSeconds))
                    if Task.isCancelled { return }
                    await store.refreshProgress(client)
                }
            }
    }
}
