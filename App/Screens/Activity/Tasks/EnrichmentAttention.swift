import SwiftUI
import FusionhaKit

/// Tasks › Needs attention (web `NeedsAttention` + `EnrichmentGroup`): the
/// files media analysis gave up on, a verdict bar by reason, then one group
/// per reason (largest first, first open) with its fix-all, a select mode for
/// bulk fixes and per-file drills; or the flat raw list.
struct EnrichmentAttentionView: View {
    let issues: [EnrichmentIssue]
    let onChanged: () async -> Void
    @State private var open: Set<String> = []
    @State private var seeded = false
    @State private var raw = false

    var body: some View {
        let groups = EnrichmentGroup.groups(issues)
        VStack(alignment: .leading, spacing: 10) {
            verdict(groups)
            if raw {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issues) { issue in EnrichmentFileRow(issue: issue, onChanged: onChanged) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                ForEach(groups) { g in
                    EnrichmentGroupCard(group: g, open: open.contains(g.reason), onChanged: onChanged) {
                        if open.contains(g.reason) { open.remove(g.reason) } else { open.insert(g.reason) }
                    }
                }
            }
            HStack(spacing: 6) {
                Text("\(ActFmt.plural(issues.count, "file")) → \(ActFmt.plural(groups.count, "problem")).")
                    .foregroundStyle(Theme.dim)
                Button(raw ? "Back to grouped view" : "Show the raw list") { raw.toggle() }
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            }
            .font(.system(size: 12))
        }
        .onAppear {
            guard !seeded, let first = groups.first else { return }
            seeded = true
            open = [first.reason]
        }
    }

    private func verdict(_ groups: [EnrichmentGroup]) -> some View {
        let total = max(1, issues.count)
        return VStack(alignment: .leading, spacing: 8) {
            (Text("\(issues.count.formatted()) file\(issues.count == 1 ? " needs" : "s need") attention").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text("  grouped by what’s wrong").foregroundColor(Theme.mut))
                .font(.system(size: 13.5))
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(groups) { g in
                        Capsule().fill(Self.color(g.tone))
                            .frame(width: max(4, geo.size.width * Double(g.issues.count) / Double(total) - 2))
                    }
                }
            }
            .frame(height: 6)
            ActFlow(spacing: 12, lineSpacing: 6) {
                ForEach(groups) { g in
                    HStack(spacing: 5) {
                        Circle().fill(Self.color(g.tone)).frame(width: 7, height: 7)
                        Text(g.heading).foregroundStyle(Theme.mut)
                        Text("\(g.issues.count)").fontWeight(.bold).foregroundStyle(Theme.txt)
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func color(_ tone: EnrichmentGroup.Tone) -> Color {
        switch tone {
        case .blocked: return Theme.danger
        case .wrong: return Theme.miss
        case .skip: return Theme.dim
        }
    }

    static func mono(_ tone: EnrichmentGroup.Tone) -> MonoToken? {
        switch tone {
        case .blocked: return .danger
        case .wrong: return .miss
        case .skip: return nil
        }
    }
}
