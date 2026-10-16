import SwiftUI
import FusionhaKit

/// One triage row (web `TriageRow`, as the phone's tap card): accept, the
/// source folders, the TMDB match with its badges, each version's tier chip and
/// the cut, the confidence pill, the profile and monitoring. Tap to edit;
/// swipe or long-press to override the match.
struct ImportTriageRow: View {
    let item: LibraryImportItem
    let profileName: String
    let editable: Bool
    let bulkSet: Bool
    let onAccept: (Bool) -> Void
    let onOpen: () -> Void
    let onOverride: () -> Void

    private var locked: Bool { !item.matched || !editable }
    private var tone: LibraryImportTone { LibraryImportRules.tone(item) }
    private var versions: [LibraryImportVersion] { item.versions ?? [] }
    private var edition: String {
        let text = item.variant ?? versions.first?.edition ?? ""
        return text.isEmpty ? "Standard" : text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Button { onAccept(!item.accepted) } label: {
                Image(systemName: item.accepted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(item.accepted ? Theme.i1 : Theme.dim)
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("Accept \(item.title)")
            .accessibilityValue(item.accepted ? "Accepted" : "Not accepted")

            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 8) {
                    details
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.dim)
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .opacity(item.alreadyImported == true ? 0.75 : 1)
        .swipeActions(edge: .trailing) {
            if editable {
                Button(item.matched ? "Override" : "Match", systemImage: "arrow.triangle.swap", action: onOverride)
                    .tint(Theme.i1)
            }
        }
        .contextMenu {
            if editable {
                Button(item.matched ? "Override match" : "Find match", systemImage: "arrow.triangle.swap", action: onOverride)
            }
            Button("Edit", systemImage: "pencil", action: onOpen)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(versions, id: \.self) { v in
                Text(v.folder).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim).lineLimit(1)
            }
            if item.matched {
                Text("→ \(item.title)").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                badges
            } else {
                Text("→ No match found").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.miss)
            }
            chips
        }
    }

    private var badges: some View {
        FetchFlow(spacing: 6, lineSpacing: 5) {
            Text("\(item.year.map(String.init) ?? "—") · \(item.kind == .series ? "Series" : "Movie")")
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
            if item.matchedBy == "id" { badge("exact · by id", Theme.done) }
            if item.alreadyImported == true { badge("Already in library", Theme.mut) }
        }
    }

    private var chips: some View {
        FetchFlow(spacing: 6, lineSpacing: 5) {
            ForEach(Array(versions.enumerated()), id: \.offset) { _, v in TierPill(tier: v.tier) }
            badge(edition, Theme.edition)
            confidence
            Text(profileName)
                .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.panel2, in: Capsule())
                .overlay(Capsule().strokeBorder(bulkSet ? Theme.cyan : .clear, lineWidth: 1.5))
            Image(systemName: item.monitored ? "bookmark.fill" : "bookmark")
                .font(.system(size: 12)).foregroundStyle(item.monitored ? Theme.i2 : Theme.dim)
                .accessibilityLabel(item.monitored ? "Monitored" : "Not monitored")
        }
    }

    private var confidence: some View {
        let color: Color = tone == .hi ? Theme.done : (tone == .lo ? Theme.miss : Theme.dim)
        let text = item.matched ? item.confidence + (tone == .lo ? " · check" : "") : "?"
        return badge(text, color)
            .accessibilityHint(tone == .lo ? "Low-confidence match — check it or override" : "")
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}
