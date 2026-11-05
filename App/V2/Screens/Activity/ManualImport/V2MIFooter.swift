import SwiftUI
import FusionhaKit

extension View {
    /// The footer pinned over a fade (the S8 `goBarInset`), unless the bulk bar has the bottom.
    @ViewBuilder
    func v2MIFooter(hidden: Bool = false) -> some View {
        if hidden {
            self
        } else {
            goBarInset { V2MIFooter() }
        }
    }
}

/// The one-row footer (mock `mi-foot`): the download's disposition, while a
/// kept file decides it, beside the prominent "✓ Import 23 · keep 2 · skip 1"
/// that applies every choice at once. An import that costs a copy you have
/// (a better or longer one) asks first. With nothing left to choose it is
/// v1's primary: Finish download (a retry) or Done.
struct V2MIFooter: View {
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @State private var confirming = false

    var body: some View {
        let plan = store.plan(session)
        let replacing = store.replacements(session)
        VStack(alignment: .leading, spacing: 8) {
            if let notice = session.notice {
                HStack(alignment: .top) {
                    Text(notice.text)
                        .font(.footnote)
                        .foregroundStyle(notice.error ? Theme.danger : Theme.stuckText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Dismiss", systemImage: "xmark") { session.notice = nil }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.mut)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                if !plan.isEmpty, let summary = store.keepSummary(session) {
                    MIDownloadDispositionMenu(summary: summary)
                }
                if plan.isEmpty {
                    fallback
                } else {
                    primary(store.counts(session).footer) {
                        if replacing.isEmpty { apply() } else { confirming = true }
                    }
                }
            }
        }
        .confirmationDialog(replaceTitle(replacing.count), isPresented: $confirming, titleVisibility: .visible) {
            Button("Import anyway", role: .destructive) { apply() }
            Button("Keep deciding", role: .cancel) {}
        } message: {
            Text(replacing.prefix(4).map(loss).joined(separator: "\n"))
        }
    }

    private var busy: Bool { store.applying || session.working || session.applying != nil }

    private func primary(_ title: String, systemImage: String = "checkmark", disabled: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if busy {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                }
                Text(busy ? "Applying…" : title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentTransition(.numericText())
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.primary)
        .disabled(busy || disabled)
        .accessibilityIdentifier("mi.v2.apply")
    }

    /// Nothing chosen here: v1's plan (Finish download, Done, or what still needs a decision).
    private var fallback: some View {
        let plan = session.plan
        return primary(plan.label, systemImage: plan.kind == .done ? "checkmark" : "internaldrive",
                       disabled: plan.disabled || plan.kind == .need) {
            Task { await session.runPrimary() }
        }
    }

    private func apply() {
        Task { await store.apply(session) }
    }

    private func replaceTitle(_ n: Int) -> String {
        n == 1 ? "Replace one of your copies?" : "Replace \(n) of your copies?"
    }

    /// "E13: Deletes your 63-min copy and keeps the 42-min cut".
    private func loss(_ row: ManualImportRow) -> String {
        let said = MIProblemCopy.consequence(.importFile, MIGroup(problem: MIProblemGrouping.problem(row), rows: [row]))
        return "\(ManualImportBulk.shortCode(row)): \(said.text)"
    }
}
