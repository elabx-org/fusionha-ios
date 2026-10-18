import SwiftUI
import FusionhaKit

extension TriageFacts.Tone {
    var color: Color { self == .ok ? Theme.done : Theme.miss }
}

/// One fact on the decision card (web `TriageTile`): an uppercase key, a bold
/// value, an optional muted line; ok / warn paint a wash, never a border.
struct TriageTileView<Extra: View>: View {
    let label: String
    let value: Text
    var sub: String?
    var tone: TriageFacts.Tone?
    var compact = false
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.dim)
            value
                .font(.system(size: compact ? 13 : 15, weight: .bold))
                .foregroundStyle(Theme.txt)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let sub, !sub.isEmpty {
                Text(sub).font(.system(size: compact ? 11 : 12.5)).foregroundStyle(Theme.mut).lineLimit(3)
            }
            extra()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 9 : 12)
        .actWash(tone?.color, radius: 12, base: Theme.panel2)
        .accessibilityElement(children: .combine)
    }
}

extension TriageTileView where Extra == EmptyView {
    init(label: String, value: Text, sub: String? = nil, tone: TriageFacts.Tone? = nil, compact: Bool = false) {
        self.init(label: label, value: value, sub: sub, tone: tone, compact: compact) { EmptyView() }
    }
}

/// "On approve · your usual setup": per tier, the root and profile a plain
/// approve uses, and Adjust (the approve dialog). `compact` is the deck's line.
struct ApproveSetupRow: View {
    let triage: RequestTriage?
    let own: Bool
    var compact = false
    let onAdjust: () -> Void

    var body: some View {
        let versions = triage?.versions ?? []
        VStack(alignment: .leading, spacing: 6) {
            if !compact {
                HStack {
                    Text("On approve · your usual setup").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                    Spacer()
                    Button("Adjust", action: onAdjust).font(.system(size: 12.5, weight: .semibold)).disabled(own)
                }
            }
            ForEach(compact ? Array(versions.prefix(1)) : versions, id: \.tier) { v in
                HStack(spacing: 8) {
                    ActTierChip(tier: v.tier)
                    Group {
                        if v.configured {
                            Text(v.rootPath ?? "").fontWeight(.semibold) + Text(" · \(v.profileName ?? "") · \(v.existing == true ? "already tracked" : "monitored")")
                        } else {
                            Text("No Add default for this version yet").foregroundColor(Theme.miss)
                        }
                    }
                    .font(.system(size: compact ? 12 : 12.5))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if compact {
                        Button("Adjust", action: onAdjust).font(.system(size: 12, weight: .semibold)).disabled(own)
                    }
                }
            }
            if triage == nil {
                Text("Loading your usual setup…").font(.system(size: compact ? 12 : 12.5)).foregroundStyle(Theme.dim)
            }
        }
        .padding(compact ? 0 : 12)
        .background(compact ? Color.clear : Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// What approving a season-scoped request does (web `ScopeLine`).
struct RequestScopeLine: View {
    let request: MediaRequest
    let triage: RequestTriage?
    var compact = false

    var body: some View {
        if let copy = RequestScope.copy(request, existing: RequestScope.existing(request, triage: triage), requested: request.tiers) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "square.stack.3d.up").font(.system(size: 13)).foregroundStyle(Theme.unaired)
                (Text(copy.lead).fontWeight(.semibold) + Text(compact ? "" : copy.tail))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(compact ? 1 : nil)
                Spacer(minLength: 0)
            }
            .padding(10)
            .actWash(Theme.unaired, radius: 10, base: Theme.panel2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.text)
        }
    }
}

/// The guard that held an automatic approval (web `HeldNote`).
struct RequestHeldNote: View {
    let held: RequestHeld

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "hand.raised.fill").font(.system(size: 12)).foregroundStyle(Theme.miss)
            (Text("The guard ") + Text(held.label).fontWeight(.bold) + Text(" stopped this request from being approved automatically."))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.txt)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .actWash(Theme.miss, radius: 10, base: Theme.panel2)
    }
}
