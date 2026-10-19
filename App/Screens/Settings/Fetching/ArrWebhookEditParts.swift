import SwiftUI
import FusionhaKit

// The pieces of the native arr webhook sheet (`ArrWebhookEditDialog.tsx`):
// the grouped "Trigger on" chips, header rows and path mapping rows.

extension ArrWebhookTriggerGroup {
    /// The group dot and the selected chip's tint (web `TRIGGER_GROUPS`).
    var accent: Color {
        switch self {
        case .library: return Theme.i2
        case .removals: return Theme.edition
        case .problems: return Theme.miss
        case .system: return Theme.unaired
        }
    }
}

extension ArrWebhookTrigger {
    /// SF Symbols for the web's trigger glyphs.
    var symbol: String {
        switch self {
        case .onGrab: return "arrow.down.circle"
        case .onMediaAdded: return "plus"
        case .onImport: return "square.and.arrow.down"
        case .onUpgrade: return "arrow.up.circle"
        case .onRename: return "pencil.line"
        case .onMediaRemoved: return "minus"
        case .onDelete: return "trash"
        case .onDeleteForUpgrade: return "arrow.triangle.swap"
        case .onManualInteractionRequired: return "hand.raised"
        case .onImportFailure: return "xmark.circle"
        case .onDownloadFailure: return "nosign"
        case .onHealthIssue: return "heart.slash"
        case .onHealthRestored: return "heart"
        case .onApplicationUpdate: return "arrow.triangle.2.circlepath"
        }
    }
}

/// One trigger group: a dot + label, then its chips (role: checkbox).
struct ArrWebhookTriggerGroupView: View {
    let group: ArrWebhookTriggerGroup
    @Binding var draft: ArrWebhookDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(group.accent).frame(width: 7, height: 7)
                Text(group.label.uppercased())
                    .font(.system(size: 11, weight: .heavy)).tracking(0.6)
                    .foregroundStyle(Theme.dim)
            }
            .accessibilityHidden(true)
            FetchFlow(spacing: 6, lineSpacing: 6) {
                ForEach(ArrWebhookTrigger.inGroup(group)) { trigger in chip(trigger) }
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ trigger: ArrWebhookTrigger) -> some View {
        let on = draft.isOn(trigger)
        return Button {
            draft.triggers[trigger] = !on
        } label: {
            HStack(spacing: 5) {
                Image(systemName: trigger.symbol).font(.system(size: 11, weight: .semibold))
                Text(trigger.label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(on ? group.accent : Theme.mut)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(on ? group.accent.opacity(0.16) : Theme.panel2, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(trigger.label)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .sensoryFeedback(.selection, trigger: on)
    }
}

/// Custom header rows: a masked stored value reads "set" with an empty input.
struct ArrWebhookHeaderRows: View {
    @Binding var rows: [SecretHeaderRow]

    var body: some View {
        ForEach($rows) { $row in
            HStack(spacing: 8) {
                TextField("Header", text: $row.key)
                    .font(.system(size: 13, design: .monospaced))
                Text(":").foregroundStyle(Theme.dim)
                TextField(row.stored ? "set (unchanged)" : "value", text: $row.value)
                    .font(.system(size: 13, design: .monospaced))
                FetchIconButton(systemName: "trash", label: "Remove header \(row.key)", danger: true) {
                    rows.removeAll { $0.id == row.id }
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        Button("Add header", systemImage: "plus") { rows.append(SecretHeaderRow()) }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accentText)
    }
}

/// Path prefix rewrites, `from → to`.
struct ArrWebhookPathMappingRows: View {
    @Binding var mappings: [ArrWebhookPathMapping]

    var body: some View {
        Text("Rewrites a path prefix in the paths this webhook sends to the receiving app. Most setups leave this empty. The longest matching “from” prefix wins when several are configured.")
            .font(.system(size: 12)).foregroundStyle(Theme.mut)
            .fixedSize(horizontal: false, vertical: true)
        ForEach($mappings) { $mapping in
            HStack(spacing: 8) {
                TextField("/data/torrents", text: $mapping.from)
                    .accessibilityLabel("Path mapping from")
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
                TextField("/downloads", text: $mapping.to)
                    .accessibilityLabel("Path mapping to")
                FetchIconButton(systemName: "trash", label: "Remove path mapping", danger: true) {
                    mappings.removeAll { $0.id == mapping.id }
                }
            }
            .font(.system(size: 13, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        Button("Add mapping", systemImage: "plus") { mappings.append(ArrWebhookPathMapping(from: "", to: "")) }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accentText)
    }
}
