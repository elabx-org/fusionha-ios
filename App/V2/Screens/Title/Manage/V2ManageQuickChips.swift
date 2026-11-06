import SwiftUI
import FusionhaKit

/// The quick chips under the scope line (mock frame 1): All · None · one
/// chip per season (filled with the accent once that whole season is
/// selected) · Select by ▾ (release group, quality, larger than…). Glass
/// controls; they scroll sideways when the folded Duo is too narrow.
struct V2ManageQuickChips: View {
    let model: ManageFilesModel
    let groups: [ManageSeasonGroup]

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    chip("All", on: model.allSelected) { model.selected = Set(model.items.map(\.id)) }
                    chip("None", on: false) { model.selected = [] }
                    if groups.count > 1 {
                        ForEach(groups) { group in
                            let state = ManageEpisodes.state(group, selected: model.selected)
                            chip(group.shortTitle, on: state == .all) {
                                model.selected = ManageEpisodes.toggling(group, in: model.selected)
                            }
                            .accessibilityLabel(group.title)
                            .accessibilityValue(V2ManageSpeech.state(state))
                        }
                    }
                    selectBy
                }
                .padding(.horizontal, 16)
            }
        }
        .scrollIndicators(.hidden)
        .disabled(model.busy || model.deleting != nil)
    }

    private func chip(_ title: String, on: Bool, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.txt)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var selectBy: some View {
        Menu {
            Section("Select by") {
                Menu("Release group") {
                    ForEach(ManageEpisodes.releaseGroups(groups), id: \.self) { name in
                        Button(name) { model.selected = ManageEpisodes.ids(groups, releaseGroup: name) }
                    }
                }
                Menu("Quality") {
                    ForEach(ManageEpisodes.qualities(groups), id: \.self) { code in
                        Button(FileNameFacts.qualityText(code) ?? code) { model.selected = ManageEpisodes.ids(groups, quality: code) }
                    }
                }
                let steps = ManageEpisodes.sizeSteps(groups)
                Menu("Larger than…") {
                    ForEach(steps, id: \.self) { gb in
                        Button("\(Int(gb)) GB") {
                            model.selected = ManageEpisodes.ids(groups, largerThan: gb * ManageEpisodes.gigabyte)
                        }
                    }
                }
                .disabled(steps.isEmpty)
            }
        } label: {
            HStack(spacing: 4) {
                Text("Select by")
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}
