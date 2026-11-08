import SwiftUI
import FusionhaKit

/// v2's Requests views drawer (mock requests.js `drawerSheet`): the
/// "Requests" heading and the need-you line, then one grouped card of the
/// views (the hued icon tile, the accent on the current one, its count and
/// a check), and Rules in its own card ("In Settings › Requests"). The rows
/// are solid content on the system's glass sheet. Same figures and actions
/// as v1's `RequestsViewMenuSheet`.
struct V2RequestsDrawerSheet: View {
    @Environment(RequestsNav.self) private var nav
    let counts: [RequestsPane: String]
    let panes: [RequestsPane]
    var needYou: Int?
    var breakdown: String?
    var showsRules = true
    let onRules: () -> Void

    private static let rowHeight: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Requests")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                if let breakdown {
                    Text(breakdown).font(.footnote).foregroundStyle(Theme.mut).lineLimit(2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
            group {
                ForEach(Array(panes.enumerated()), id: \.element) { i, pane in
                    if i > 0 { divider }
                    row(pane)
                }
            }
            if showsRules {
                group {
                    Button(action: onRules) {
                        V2AccountRow(icon: "slider.horizontal.3", tint: Theme.dim, title: "Rules",
                                     subtitle: "In Settings › Requests", accessory: .external)
                            .padding(.horizontal, 14)
                            .frame(minHeight: Self.rowHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: nav.pane)
    }

    private var height: CGFloat {
        CGFloat(panes.count) * Self.rowHeight + (showsRules ? 170 : 96) + (breakdown == nil ? 0 : 22)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(AccountStyle.cell, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 0.5).padding(.leading, 54)
    }

    private func row(_ pane: RequestsPane) -> some View {
        let on = nav.pane == pane
        return Button { nav.open(pane) } label: {
            HStack(spacing: 8) {
                V2AccountRow(icon: pane.icon, tint: on ? Theme.i1 : Theme.dim, title: pane.title,
                             subtitle: pane == .issues ? needYou.map { "\($0) need you" } : nil,
                             value: counts[pane], accessory: .none)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .opacity(on ? 1 : 0)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
