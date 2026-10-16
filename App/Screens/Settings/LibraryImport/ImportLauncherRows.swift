import SwiftUI
import FusionhaKit

/// One draft to resume (web `ResumeCard`): the auto-saved time, the roots it
/// covers, the Matched / Needs you / Ready / Files tallies, Resume and Discard.
struct ImportResumeCard: View {
    let draft: LibraryImportSummary
    let onResume: () -> Void
    let onDiscard: () async -> Void
    @State private var confirming = false
    @State private var discarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Draft import", systemImage: "circle.fill")
                    .labelStyle(ImportDotLabelStyle(color: Theme.miss))
                Spacer()
                Text("auto-saved \(ActFmt.relative(draft.updatedAt))")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            Text("Resume where you left off").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.txt)
            MonoText(LibraryImportRules.rootLabel(draft)).lineLimit(2)
            HStack(spacing: 8) {
                tally(draft.matched ?? 0, "Matched", Theme.txt)
                tally(draft.needsYou ?? 0, "Needs you", Theme.miss)
                tally(draft.ready ?? 0, "Ready", Theme.done)
                tally(draft.files ?? 0, "Files to adopt", Theme.txt)
            }
            HStack(spacing: 8) {
                Button("Resume import", action: onResume).buttonStyle(.web(.primary))
                Button(discarding ? "Discarding…" : "Discard") { confirming = true }
                    .buttonStyle(.web()).disabled(discarding)
                Spacer(minLength: 0)
            }
            Text("opens the import workspace").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 6)
        .confirmationDialog("Discard this draft?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                Task {
                    discarding = true
                    await onDiscard()
                    discarding = false
                }
            }
        } message: {
            Text("Files on disk are untouched.")
        }
    }

    private func tally(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LibraryImportRules.grouped(n)).font(.system(size: 17, weight: .heavy).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.mut).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small coloured dot before the title (the web's badge dot).
struct ImportDotLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            configuration.title.font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
        }
    }
}

/// One root in the picker: include it, and the tier and kind to scan it as.
struct ImportRootPickRow: View {
    let path: String
    let choice: ImportRootChoice
    let onChange: (ImportRootChoice) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                var next = choice
                next.selected.toggle()
                onChange(next)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: choice.selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19))
                        .foregroundStyle(choice.selected ? Theme.i1 : Theme.dim)
                    Image(systemName: "folder").font(.system(size: 14)).foregroundStyle(Theme.mut)
                    Text(path)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(choice.selected ? Theme.txt : Theme.mut)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Include \(path)")
            .accessibilityValue(choice.selected ? "Selected" : "Not selected")

            Menu {
                Picker("Tier", selection: tierBinding) {
                    Text(QualityTier.hd.chipLabel).tag(QualityTier.hd)
                    Text(QualityTier.uhd.chipLabel).tag(QualityTier.uhd)
                }
            } label: {
                TierPill(tier: choice.tier)
            }
            .accessibilityLabel("Tier for \(path): \(choice.tier.chipLabel)")

            Menu {
                Picker("Kind", selection: kindBinding) {
                    Text("Movies").tag(MediaKind.movie)
                    Text("Series").tag(MediaKind.series)
                }
            } label: {
                Text(LibraryImportRules.kindLabel(choice.kind))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.panel2, in: Capsule())
            }
            .accessibilityLabel("Kind for \(path): \(LibraryImportRules.kindLabel(choice.kind))")
        }
        .opacity(choice.selected ? 1 : 0.85)
    }

    private var tierBinding: Binding<QualityTier> {
        Binding(get: { choice.tier }, set: { t in
            var next = choice
            next.tier = t
            onChange(next)
        })
    }

    private var kindBinding: Binding<MediaKind> {
        Binding(get: { choice.kind }, set: { k in
            var next = choice
            next.kind = k
            onChange(next)
        })
    }
}

/// Recent imports: each job's post-import analysis card, then the committed
/// imports, read-only (View report re-opens the workspace).
struct ImportRecentSection: View {
    let recent: [LibraryImportSummary]
    let onView: (Int) -> Void
    let onChanged: () async -> Void

    var body: some View {
        SettingsSection("Recent imports") {
            ForEach(recent) { r in
                if let task = r.enrichment, LibraryImportTaskView(task).visible {
                    ImportPostTaskCard(sessionId: r.id, enrichment: task, onChanged: onChanged)
                }
            }
            ForEach(recent) { r in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(LibraryImportRules.plural(r.sources ?? 0, "source")) imported")
                            .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                        Text(ActFmt.relative(r.updatedAt)).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                    Spacer(minLength: 8)
                    Button("View report") { onView(r.id) }.buttonStyle(.web())
                }
            }
        }
    }
}
