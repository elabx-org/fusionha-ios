import SwiftUI

/// The "Coming up" header's menu, a glass pill naming the preset ("Mix"):
/// the presets, then the movie and series toggles, then the window, and on
/// the open Duo its look (Posters or Backdrops); half folded on a table, the
/// Hologram toggle (`V2TabletopHologram`). The kind toggles keep the menu
/// open so several can change in one visit.
struct V2ComingUpMenu: View {
    @Binding var kindsRaw: String
    @Binding var days: Int
    /// The open Duo's look (`V2ComingUpWideStyle`); nil leaves the section out.
    var wideStyle: Binding<String>?
    /// Half folded on a table: the menu also has the Hologram toggle.
    var onTable = false
    @AppStorage(V2TabletopHologram.key) private var hologram = false
    @Environment(\.pagePalette) private var page

    private var kinds: Set<V2ComingUpKind> { V2ComingUpSettings.decode(kindsRaw) }
    private var preset: V2ComingUpPreset? { V2ComingUpPreset.matching(kinds) }

    var body: some View {
        Menu {
            Picker("Show", selection: presetBinding) {
                ForEach(V2ComingUpPreset.allCases) { p in
                    Text(p.title).tag(Optional(p))
                }
            }
            .pickerStyle(.inline)
            Section("Movies") {
                ForEach(V2ComingUpKind.movies) { toggle($0) }
            }
            Section("Series") {
                ForEach(V2ComingUpKind.series) { toggle($0) }
            }
            Picker("Window", selection: windowBinding) {
                ForEach(V2ComingUpSettings.windows, id: \.self) { n in
                    Text("\(n) days").tag(n)
                }
            }
            .pickerStyle(.inline)
            if let wideStyle {
                Picker("Open Duo", selection: wideStyle) {
                    ForEach(V2ComingUpWideStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
            }
            if onTable {
                Section("On a table") {
                    Toggle("Hologram", systemImage: "cube", isOn: $hologram)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(preset?.title ?? "Custom")
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(page?.ink ?? Theme.txt)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel("Coming up shows \(preset?.title ?? "a custom mix"), next \(V2ComingUpSettings.window(days)) days")
        .sensoryFeedback(.selection, trigger: kindsRaw)
        .sensoryFeedback(.selection, trigger: days)
    }

    private func toggle(_ kind: V2ComingUpKind) -> some View {
        Toggle(kind.title, isOn: Binding(
            get: { kinds.contains(kind) },
            set: { on in
                var next = kinds
                if on { next.insert(kind) } else { next.remove(kind) }
                kindsRaw = V2ComingUpSettings.encode(next)
            }))
            .menuActionDismissBehavior(.disabled)
    }

    private var presetBinding: Binding<V2ComingUpPreset?> {
        Binding(get: { preset }, set: { p in
            if let p { kindsRaw = V2ComingUpSettings.encode(p.kinds) }
        })
    }

    private var windowBinding: Binding<Int> {
        Binding(get: { V2ComingUpSettings.window(days) }, set: { days = $0 })
    }
}
