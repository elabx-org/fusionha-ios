import SwiftUI
import FusionhaKit

/// The master list: General + Metadata, the three expandable groups and the
/// collapsible FETCHING and SYSTEM sections. On a phone each row is the web's
/// rich mobile row; in the split (ruling S2) the sidebar uses compact labels
/// and marks the open panel.
struct SettingsMasterList: View {
    /// The open panel, highlighted in the sidebar; `nil` on a phone.
    let selected: String?
    /// Groups and sections the user closed (all open by default, the web's `openGroups`).
    @Binding var closed: Set<String>
    let select: (String) -> Void
    @Environment(\.settingsMotionOff) private var motionOff

    private var compact: Bool { selected != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsNav.top, id: \.self) { id in
                if let panel = SettingsNav.panel(id) { row(panel) }
            }
            ForEach(SettingsNav.groups) { group in
                groupHeader(group)
                if isOpen(group.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(group.children, id: \.self) { id in
                            if let panel = SettingsNav.panel(id) { row(panel) }
                        }
                    }
                    .padding(.leading, 11)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                    .padding(.leading, 18)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(childTransition)
                }
            }
            ForEach(SettingsNav.sections) { section in
                sectionHeader(section)
                if isOpen(section.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(section.panels, id: \.self) { id in
                            if let panel = SettingsNav.panel(id) { row(panel) }
                        }
                    }
                    .transition(childTransition)
                }
            }
        }
    }

    private var childTransition: AnyTransition {
        motionOff ? .identity : .opacity.combined(with: .move(edge: .top))
    }

    private func isOpen(_ id: String) -> Bool { !closed.contains(id) }

    private func toggle(_ id: String) {
        SettingsMotion.perform(motionOff) {
            if closed.contains(id) { closed.remove(id) } else { closed.insert(id) }
        }
    }

    private func row(_ panel: SettingsPanelInfo) -> some View {
        Button { select(panel.id) } label: {
            SettingsMasterRow(panel: panel, compact: compact)
        }
        .buttonStyle(SettingsRowButtonStyle())
        .background {
            if selected == panel.id {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.panel2)
            }
        }
        .accessibilityAddTraits(selected == panel.id ? .isSelected : [])
        .padding(.top, panel.action ? 5 : 0)
        .overlay(alignment: .top) {
            if panel.action { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }

    private func groupHeader(_ group: SettingsGroupInfo) -> some View {
        Button { toggle(group.id) } label: {
            HStack(spacing: 11) {
                Image(systemName: group.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18)
                Text(group.label)
                    .font(.system(size: 13.5, weight: .bold))
                Spacer(minLength: 0)
                SettingsChevron(open: isOpen(group.id))
            }
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
        .accessibilityValue(isOpen(group.id) ? "Expanded" : "Collapsed")
    }

    private func sectionHeader(_ section: SettingsSectionInfo) -> some View {
        Button { toggle(section.id) } label: {
            HStack(spacing: 0) {
                Text(section.label.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.57)
                    .foregroundStyle(Theme.dim)
                Spacer(minLength: 0)
                SettingsChevron(open: isOpen(section.id))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.bottom, 3)
        .accessibilityValue(isOpen(section.id) ? "Expanded" : "Collapsed")
    }
}
