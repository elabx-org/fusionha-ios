import SwiftUI
import FusionhaKit

/// The Blocklist insight module (mock `bIns`): the reasons in the loaded
/// rows as one-ink bars, Retry recoverable as the one prominent button,
/// and why those can retry.
struct V2BlocklistInsight: View {
    let loaded: Int
    let counts: [BlocklistCategory: Int]
    let busy: Bool
    let retry: () -> Void
    @Environment(\.pagePalette) private var page

    var body: some View {
        let recoverable = counts[.recoverable] ?? 0
        let peak = Double(max(counts.values.max() ?? 0, 1))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("In the latest \(loaded.formatted())").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Spacer(minLength: 8)
                if recoverable > 0 {
                    V2CapsuleButton(title: "Retry \(recoverable)", systemImage: "arrow.clockwise", prominent: true,
                                    busy: busy, action: retry)
                }
            }
            ForEach([BlocklistCategory.recoverable, .manual, .permanent], id: \.self) { category in
                V2InkBarRow(label: category.label, value: (counts[category] ?? 0).formatted(),
                            fraction: Double(counts[category] ?? 0) / peak)
            }
            if recoverable > 0 {
                Text("A dead NZB may have recovered since: Retry lifts \(recoverable == 1 ? "it" : "them") and searches again.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .v2CardStyle(padding: 14)
    }
}

/// By title | Flat and the tools in one glass capsule (mock `bTools`): Show
/// reasons, Select, Release groups and Clear blocklist.
struct V2BlocklistTools: View {
    @Bindable var data: V2BlocklistModel
    let canClear: Bool
    let releaseGroups: () -> Void
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("Layout", selection: $data.grouped) {
                Text("By title").tag(true)
                Text("Flat").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
            Spacer(minLength: 0)
            GlassEffectContainer {
                HStack(spacing: 0) {
                    tool("info.circle", "Show reasons", on: data.showReasons) { data.showReasons.toggle() }
                    tool("checkmark.circle", data.selecting ? "Done selecting" : "Select", on: data.selecting) {
                        if data.selecting { data.endSelecting() } else { data.selecting = true }
                    }
                    tool("tag", "Release groups", action: releaseGroups)
                    tool("trash", "Clear blocklist", action: clear)
                        .disabled(!canClear)
                        .opacity(canClear ? 1 : 0.4)
                }
                .padding(.horizontal, 4)
                .glassEffect(.regular, in: Capsule())
            }
        }
    }

    private func tool(_ icon: String, _ label: String, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: on ? icon + ".fill" : icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? Theme.accentText : Theme.txt)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Select mode's glass bar (mock `bBulk`): the count (Select all in its
/// menu), Search again and Unblock.
struct V2BlocklistBulkBar: View {
    let count: Int
    let hint: String?
    let selectAll: () -> Void
    let searchAgain: () -> Void
    let unblock: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let hint {
                Text(hint).font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Select all loaded", systemImage: "checkmark.circle", action: selectAll)
                    } label: {
                        Text("\(count) selected")
                            .font(.system(size: 14.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.txt)
                            .padding(.leading, 18)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    action("Search again", "magnifyingglass", tint: Theme.txt, run: searchAgain)
                    action("Unblock", "arrow.uturn.backward", tint: Theme.dangerText, run: unblock)
                }
                .padding(.trailing, 8)
                .frame(height: 56)
                .glassEffect(.regular, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func action(_ label: String, _ icon: String, tint: Color, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(label, systemImage: icon)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1)
    }
}
