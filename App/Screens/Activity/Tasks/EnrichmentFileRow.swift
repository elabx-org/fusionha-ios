import SwiftUI
import FusionhaKit

/// One file that needs attention (web `EnrichmentFileRow`): an optional select
/// check, the title and file name, its fixes, and a chevron that drills into
/// what's wrong, how to fix it, the full path and an Open link.
struct EnrichmentFileRow: View {
    let issue: EnrichmentIssue
    /// Non-nil in select mode: whether this row is checked.
    var checked: Bool?
    var onToggle: () -> Void = {}
    let onChanged: () async -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.actReduceMotion) private var reduce
    @State private var open = false
    @State private var confirm: (fix: EnrichmentFix, ids: [Int])?
    @State private var busy = false

    private var group: EnrichmentGroup { EnrichmentGroup.groups([issue]).first! }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if let checked {
                    Button(action: onToggle) {
                        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(checked ? Theme.accentText : Theme.dim)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(issue.title)")
                    .accessibilityAddTraits(checked ? .isSelected : [])
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text([issue.title, issue.code].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.txt).lineLimit(1)
                    if let name = issue.fileName {
                        Text(name).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if checked == nil { fixesMenu }
                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Hide details for \(issue.title)" : "Show details for \(issue.title)")
            }
            if open { drill.transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top))) }
        }
        .padding(.top, 4)
        .disabled(busy)
        .modifier(EnrichmentConfirm(pending: $confirm) { fix, ids, disk in run(fix, ids, disk) })
    }

    private func toggle() {
        if reduce { open.toggle() } else { withAnimation(.easeOut(duration: 0.22)) { open.toggle() } }
    }

    private var fixesMenu: some View {
        Menu {
            ForEach(group.fixes, id: \.self) { fix in
                Button(fix.label, systemImage: fix.symbol, role: fix == .retry ? nil : .destructive) {
                    if fix == .retry { run(.retry, [issue.id], false) } else { confirm = (fix, [issue.id]) }
                }
            }
            if let item = issue.itemId {
                Button("Open title", systemImage: "arrow.up.forward") { model.open(item) }
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
                .frame(width: 32, height: 28).contentShape(Rectangle())
        }
        .accessibilityLabel("Fixes for \(issue.title)")
    }

    private var drill: some View {
        VStack(alignment: .leading, spacing: 8) {
            fact("What’s wrong", group.whatsWrong)
            if !group.howToFix.isEmpty { fact("How to fix", group.howToFix) }
            VStack(alignment: .leading, spacing: 2) {
                label("File")
                Text(issue.path?.isEmpty == false ? issue.path! : issue.title)
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let item = issue.itemId {
                Button("Open \(issue.mediaKind == "series" ? "episode" : "title") ↗") { model.open(item) }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func fact(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label(title)
            Text(text).font(.system(size: 12.5)).foregroundStyle(Theme.txt).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.5).foregroundStyle(Theme.dim)
    }

    private func run(_ fix: EnrichmentFix, _ ids: [Int], _ disk: Bool) {
        confirm = nil
        Task {
            busy = true
            defer { busy = false }
            await EnrichmentActions.run(fix, ids: ids, deleteFromDisk: disk, client: model.client, toaster: toaster)
            await onChanged()
        }
    }
}
