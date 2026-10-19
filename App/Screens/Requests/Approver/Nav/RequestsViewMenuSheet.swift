import SwiftUI
import FusionhaKit

/// The view drawer (owner decision, Final mock): a short system sheet with a
/// "Requests" heading, one row per view (icon, name, count, a check on the
/// current one), then Rules, which lives in Settings › Requests.
struct RequestsViewMenuSheet: View {
    @Environment(RequestsNav.self) private var nav
    /// The plain figure beside a row ("4", "4+"), only when above zero.
    let counts: [RequestsPane: String]
    let panes: [RequestsPane]
    /// Issues: how many of the open ones need an admin ("2 need you").
    var needYou: Int?
    /// "11 need you · 9 pending requests · 2 issues".
    var breakdown: String?
    var showsRules = true
    let onRules: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Requests")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            if let breakdown {
                Text(breakdown).font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .padding(.horizontal, 12).padding(.bottom, 8)
            }
            ForEach(panes) { pane in row(pane) }
            if showsRules {
            Divider().overlay(Theme.line).padding(.horizontal, 10).padding(.vertical, 6)
            Button(action: onRules) {
                HStack(spacing: 14) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 17)).foregroundStyle(Theme.mut).frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rules").font(.system(size: 16)).foregroundStyle(Theme.txt)
                        Text("In Settings › Requests").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(CGFloat(panes.count) * 52 + (showsRules ? 150 : 90) + (breakdown == nil ? 0 : 26))])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
        .sensoryFeedback(.selection, trigger: nav.pane)
    }

    private func row(_ pane: RequestsPane) -> some View {
        let on = nav.pane == pane
        return Button { nav.open(pane) } label: {
            HStack(spacing: 14) {
                Image(systemName: pane.icon).font(.system(size: 17)).foregroundStyle(Theme.mut).frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title).font(.system(size: 16)).foregroundStyle(Theme.txt)
                    if pane == .issues, let needYou {
                        Text(verbatim: "\(needYou) need you").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                }
                Spacer()
                if let n = counts[pane] {
                    Text(verbatim: n).font(.system(size: 14).monospacedDigit()).foregroundStyle(Theme.mut)
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accentText)
                    .opacity(on ? 1 : 0)
                    .frame(width: 18)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 50)
            .background(on ? Theme.txt.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
