import SwiftUI
import FusionhaKit

/// "Versions" (web `TierCards`, phone layout): one card per tier, stacked.
/// HD·1080p is marked Default and on; UHD·4K is off. An ON card wears a faint
/// tier tint with an inset tier ring and shows its Folder / Profile / Edition
/// rows (native menus); an OFF card offers a dashed "Add a 4K version". Both
/// end in a bottom row: HD's "the copy most people watch", UHD's 4K check.
struct AddTierCards: View {
    let flow: AddFlow

    var body: some View {
        VStack(spacing: 12) {
            ForEach(AddFlow.tiers, id: \.self) { tier in
                if let state = flow.versions?[tier] {
                    AddTierCard(flow: flow, tier: tier, state: state)
                }
            }
        }
    }
}

private struct AddTierCard: View {
    let flow: AddFlow
    let tier: QualityTier
    let state: AddTierState
    @Environment(\.motionEnabled) private var motion

    private static let standard = "Standard"
    private var label: String { AddVocab.tierLabel(tier) }
    private var edition: String { flow.editions[tier] ?? Self.standard }

    /// Standard first; the chosen cut stays selectable even when disabled.
    private var editionList: [String] {
        var list = [Self.standard] + flow.editionNames.filter { $0 != Self.standard }
        if !list.contains(edition) { list.append(edition) }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.17)
                    .foregroundStyle(tier.color)
                if tier == .hd {
                    Text("DEFAULT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(Theme.done)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.done.opacity(0.4)))
                }
                Spacer(minLength: 0)
                Toggle(label, isOn: Binding(get: { state.on }, set: { on in
                    withAnimation(motion ? .snappy(duration: 0.3) : nil) { flow.setTierOn(tier, on) }
                }))
                .labelsHidden()
                .tint(tier.color)
            }
            .frame(minHeight: 26)
            if state.on {
                rows.transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button {
                    withAnimation(motion ? .snappy(duration: 0.3) : nil) { flow.setTierOn(tier, true) }
                } label: {
                    Label("Add a \(tier == .hd ? "HD" : "4K") version", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.txt.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
            }
            if tier == .hd {
                AvailRow(tone: Theme.edition, icon: { Text("HD") },
                         title: Text("The copy most people watch"),
                         sub: AnyView(availSub("Added by default · searched on add")))
            } else {
                FourKRow(flow: flow)
            }
        }
        .padding(14)
        .background(state.on ? tier.color.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(state.on ? tier.color.opacity(0.22) : Theme.line))
        .opacity(state.on ? 1 : 0.78)
        .sensoryFeedback(.selection, trigger: state.on)
    }

    /// The ≥48pt Folder / Profile / Edition rows, each a native menu.
    private var rows: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            pickRow("Folder", value: flow.roots?.first { $0.id == state.rootId }?.path ?? "",
                    options: (flow.roots ?? []).map { ($0.id, $0.path) }, selected: state.rootId) {
                flow.patchTier(tier, rootId: $0)
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            pickRow("Profile", value: flow.profileOptions.first { $0.id == state.profileId }?.name ?? "",
                    options: flow.profileOptions.map { ($0.id, $0.name) }, selected: state.profileId) {
                flow.patchTier(tier, profileId: $0)
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            Menu {
                Picker("\(label) · Edition", selection: Binding(get: { edition }, set: { flow.setEdition(tier, $0) })) {
                    ForEach(editionList, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                rowLabel("Edition", value: edition, valueColor: edition == Self.standard ? Theme.mut : Theme.anime)
            }
        }
        .padding(.horizontal, -14)
    }

    private func pickRow(_ title: String, value: String, options: [(Int, String)], selected: Int,
                         choose: @escaping (Int) -> Void) -> some View {
        Menu {
            Picker("\(label) · \(title)", selection: Binding(get: { selected }, set: choose)) {
                ForEach(options, id: \.0) { option in Text(option.1).tag(option.0) }
            }
        } label: {
            rowLabel(title, value: value, valueColor: Theme.mut)
        }
    }

    private func rowLabel(_ title: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13.5))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}
