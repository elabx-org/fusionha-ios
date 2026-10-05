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
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
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
                            .strokeBorder(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
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

private func availSub(_ text: String) -> some View {
    Text(text).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(1)
}

/// The bottom row of a tier card: tinted icon tile, title + one subline, action.
private struct AvailRow<Icon: View, Action: View>: View {
    let tone: Color
    let icon: Icon
    let title: Text
    let sub: AnyView
    var shimmer = false
    let action: Action

    init(tone: Color, @ViewBuilder icon: () -> Icon, title: Text, sub: AnyView, shimmer: Bool = false,
         @ViewBuilder action: () -> Action) {
        self.tone = tone
        self.icon = icon()
        self.title = title
        self.sub = sub
        self.shimmer = shimmer
        self.action = action()
    }

    var body: some View {
        HStack(spacing: 10) {
            icon
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(tone)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                title
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .frame(height: 18)
                sub.frame(height: 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(tone.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { if shimmer { Color.clear.shimmer().clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) } }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(tone.opacity(0.18)))
    }
}

extension AvailRow where Action == EmptyView {
    init(tone: Color, @ViewBuilder icon: () -> Icon, title: Text, sub: AnyView, shimmer: Bool = false) {
        self.init(tone: tone, icon: icon, title: title, sub: sub, shimmer: shimmer) { EmptyView() }
    }
}

/// The UHD card's 4K availability row. The check is manual: Check when idle,
/// ↻ after a result, Try again after an error. The best release's name shows
/// on a long press.
private struct FourKRow: View {
    let flow: AddFlow
    @State private var showBest = false

    private enum RowState { case idle, checking, found, none, soon, error }

    private func plural(_ n: Int, _ one: String) -> String { "\(n) \(one)\(n == 1 ? "" : "s")" }

    private var rowState: RowState {
        switch flow.fourKStatus {
        case .idle: return .idle
        case .checking: return .checking
        case .error: return .error
        case .done:
            guard let r = flow.fourKResult else { return .error }
            if r.foundUhd == true { return .found }
            return flow.notOutYet(flow.timeline()) ? .soon : .none
        }
    }

    var body: some View {
        let state = rowState
        let r = flow.fourKResult
        let best = state == .found ? r?.bestReleaseName : nil
        Group {
            switch state {
            case .idle:
                AvailRow(tone: Theme.mut, icon: { Text("4K") }, title: Text("Not checked yet"),
                         sub: AnyView(availSub("See if a genuine 4K release exists before adding"))) {
                    Button { check() } label: {
                        Label("Check", systemImage: "magnifyingglass")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Theme.i2)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Theme.i2.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.i2.opacity(0.55)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            case .checking:
                AvailRow(tone: Theme.i2, icon: { ProgressView().controlSize(.mini).tint(Theme.i2) },
                         title: Text(flow.fourKLastCount.map { "Searching \(plural($0, "indexer"))…" } ?? "Searching your indexers…"),
                         sub: AnyView(availSub("Looking for genuine 2160p releases")), shimmer: true)
            case .found:
                let seasons = flow.isSeries ? (r?.seasonsSeen ?? []).compactMap { $0 } : []
                let meta = ([plural(r?.queriedIndexers ?? 0, "indexer")] + (seasons.isEmpty ? [] : [seasons.map { "S\($0)" }.joined(separator: ", ")]))
                    .joined(separator: " · ")
                let tags = r?.formatTags ?? []
                AvailRow(tone: Theme.done, icon: { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)) },
                         title: Text("Genuine 4K found ") + Text("· \(meta)").fontWeight(.medium).foregroundColor(Theme.mut),
                         sub: tags.isEmpty ? AnyView(availSub(best ?? "A genuine 2160p release")) : AnyView(tagLine(tags))) {
                    recheck("Check again")
                }
            case .none:
                let text = r?.dispatched == false && !(r?.message ?? "").isEmpty
                    ? (r?.message ?? "") : "\(plural(r?.queriedIndexers ?? 0, "indexer")) · only upscales found"
                AvailRow(tone: Theme.miss, icon: { Text("!") }, title: Text("No genuine 4K yet"), sub: AnyView(availSub(text))) {
                    recheck("Check again")
                }
            case .soon:
                AvailRow(tone: Theme.unaired, icon: { Image(systemName: "clock").font(.system(size: 13, weight: .bold)) },
                         title: Text("Not out yet"), sub: AnyView(availSub("4K will be searched on release"))) {
                    recheck("Check anyway")
                }
            case .error:
                AvailRow(tone: Theme.miss, icon: { Text("!") }, title: Text("Couldn’t check"),
                         sub: AnyView(availSub("The indexer search didn’t finish"))) {
                    Button("Try again") { check() }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Theme.i2)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Theme.i2.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.i2.opacity(0.55)))
                        .buttonStyle(PressScaleStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(best.map { "Best release: \($0)" } ?? "")
        .onLongPressGesture(minimumDuration: 0.45) { if best != nil { showBest = true } }
        .popover(isPresented: $showBest) {
            Text(best ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.txt)
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.success, trigger: state == .found)
    }

    private func check() {
        Task { await flow.checkFourK() }
    }

    private func recheck(_ label: String) -> some View {
        Button { check() } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }

    /// The found row's CF chips: one line, clipped.
    private func tagLine(_ tags: [FourKAvailabilityTag]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                let color = Self.tagColor(tag.kind)
                Text(tag.label)
                    .font(.system(size: 10, weight: .semibold, design: tag.kind == "group" ? .monospaced : .default))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.14), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    /// `FORMAT_TAG_COLOR`.
    private static func tagColor(_ kind: String?) -> Color {
        switch kind {
        case "quality": return Theme.grab
        case "hdr": return Theme.miss
        case "audio": return Theme.done
        case "group": return Theme.edition
        default: return Theme.mut
        }
    }
}
