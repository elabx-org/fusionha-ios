import SwiftUI
import FusionhaKit

/// A sentence built from `SummaryPart`s: strong parts in the text colour.
struct AddSummaryText: View {
    let parts: [SummaryPart]
    var prefix: String?

    var body: some View {
        parts.reduce(prefix.map { Text("\($0) ").fontWeight(.bold).foregroundColor(Theme.txt) } ?? Text("")) { text, part in
            text + (part.strong ? Text(part.text).fontWeight(.semibold).foregroundColor(Theme.txt) : Text(part.text))
        }
        .foregroundStyle(Theme.mut)
        .fixedSize(horizontal: false, vertical: true)
        .contentTransition(.opacity)
        .animation(.easeOut(duration: 0.2), value: parts.map(\.text).joined())
    }
}

// The configure step's sticky footer: the live sentence, Search now and the
// Add button with its fill, then ✓ Added.
extension AddConfigView {
    func footer(_ timeline: ReleaseTimelineModel) -> some View {
        let split = flow.onTiers.count == 2
            && (splitChosen || (flow.versions?[.uhd]?.monitor ?? flow.monitor) != flow.monitor)
        let stop = timeline.stops.first { $0.key == flow.minAvail } ?? timeline.stops[0]
        let parts = AddSentence.summary(
            isSeries: flow.isSeries,
            versions: flow.onTiers.map { ($0, flow.editions[$0]) },
            searchNow: flow.searchNow,
            monitor: flow.isSeries ? flow.monitorSummary(flow.monitor, withCustom: !split) : nil,
            monitorUhd: flow.isSeries && split ? flow.monitorSummary(flow.versions?[.uhd]?.monitor ?? flow.monitor, withCustom: false) : nil,
            stop: flow.isSeries ? nil : (label: stop.label, dateText: stop.dateText))
        let busy = phase == .progress || (flow.isAdding && phase != .done)
        let done = phase == .done
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                AddSummaryText(parts: parts).font(.system(size: 13.5))
                if let error = flow.error, !error.folder {
                    Text(error.message).font(.system(size: 12.5)).foregroundStyle(Theme.danger)
                }
            }
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { flow.searchNow }, set: { flow.searchNow = $0 })) {
                    Text("Search now").font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                .toggleStyle(AddLeadingSwitchStyle())
                .frame(minHeight: 44)
                .fixedSize()
                Button { Task { await add() } } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle().fill(Theme.onAccent.opacity(0.18))
                                .frame(width: geo.size.width * (phase == .done ? 1 : phase == .progress ? 0.9 : 0))
                        }
                        Text(done ? "✓ Added" : busy ? "Adding…" : "Add \(flow.isSeries ? "series" : "movie")")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .contentTransition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    .background {
                        if done {
                            Theme.done
                        } else {
                            // The palette's primary, like every other main button.
                            Theme.primary
                        }
                    }
                    .clipShape(Capsule())
                    .saturation(!done && !busy && !flow.canSubmit ? 0.2 : 1)
                    .brightness(!done && !busy && !flow.canSubmit ? -0.3 : 0)
                    .scaleEffect(busy && motion ? 0.97 : 1)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .disabled(!done && (!flow.canSubmit || busy))
                .allowsHitTesting(!done)
                .accessibilityLabel(done ? "Added" : busy ? "Adding" : "Add \(flow.isSeries ? "series" : "movie")")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Theme.panel.opacity(0.5)), in: .rect(cornerRadius: 0))
        // A scrim under the glass that runs to the screen edge, so the page
        // never reads through the bar or shows below it.
        .background { Theme.bg.opacity(0.88).ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .sensoryFeedback(.success, trigger: done)
    }

    /// The add moment: fill → ✓ Added → close. An error resets the button and
    /// shows inline (on the Folder row for a 409 collision).
    func add() async {
        guard phase == .idle, flow.canSubmit else { return }
        let started = Date()
        withAnimation(motion ? .timingCurve(0.22, 1, 0.36, 1, duration: Double(Self.fillMs) / 1000) : nil) { phase = .progress }
        guard let item = await flow.submit() else {
            phase = .idle
            return
        }
        if motion {
            let left = Self.fillMs - Int(Date().timeIntervalSince(started) * 1000)
            if left > 0 { try? await Task.sleep(for: .milliseconds(left)) }
        }
        withAnimation(motion ? .easeOut(duration: 0.2) : nil) { phase = .done }
        try? await Task.sleep(for: .milliseconds(Self.doneMs))
        onAdded(item)
    }
}

/// The footer's switch with its label after it ("[switch] Search now").
struct AddLeadingSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: configuration.$isOn).toggleStyle(.switch).labelsHidden().tint(Theme.indigo)
            configuration.label
        }
        .contentShape(Rectangle())
    }
}
