import SwiftUI
import FusionhaKit

/// "What to monitor" (web `MonitorStrip`, phone layout): the ten Sonarr modes
/// as chips, a season list whose lit ticks are exactly the episodes the mode
/// will monitor, and a live count sentence. With both versions on, "Different
/// for 4K" splits it into an HD and a 4K row, each with its own mode. Press and
/// hold a season, then slide, to choose where monitoring starts.
struct AddMonitorStrip: View {
    let flow: AddFlow
    @Binding var splitChosen: Bool
    @Binding var editingRow: QualityTier
    @Environment(\.motionEnabled) private var motion
    @Environment(\.addLook) private var look

    private var hdOn: Bool { flow.versions?[.hd]?.on ?? false }
    private var uhdOn: Bool { flow.versions?[.uhd]?.on ?? false }
    private var uhdMonitor: String { flow.versions?[.uhd]?.monitor ?? flow.monitor }
    /// A lingering per-version override always shows as the split view.
    var split: Bool { hdOn && uhdOn && (splitChosen || uhdMonitor != flow.monitor) }

    var body: some View {
        let seasons = flow.seasons ?? []
        let hasStrip = !seasons.isEmpty
        let custom = flow.hasCustomSeasons && !split && !flow.effectiveAnime
        let hdPreview: MonitorPreview? = hasStrip
            ? SeasonSlider.apply(seasons, MonitorPreview.compute(seasons, mode: flow.monitor), custom ? flow.seasonFrom : [:])
            : nil
        let uhdPreview: MonitorPreview? = hasStrip && split ? MonitorPreview.compute(seasons, mode: uhdMonitor) : nil
        let editingUhd = split && editingRow == .uhd
        let chipValue = editingUhd ? uhdMonitor : flow.monitor

        VStack(alignment: .leading, spacing: 12) {
            PreviewFlow(spacing: 6) {
                ForEach(AddVocab.monitorOptions, id: \.value) { option in
                    chip(option.label, selected: !custom && chipValue == option.value) {
                        if editingUhd { flow.setTierMonitor(.uhd, option.value) } else { setMaster(option.value) }
                    }
                }
                if custom { chip("Custom", selected: true) {} }
            }
            .sensoryFeedback(.selection, trigger: chipValue)
            VStack(alignment: .leading, spacing: 10) {
                if split {
                    Picker("Choice applies to", selection: $editingRow) {
                        Text("HD·1080p").tag(QualityTier.hd)
                        Text("UHD·4K").tag(QualityTier.uhd)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                if let hdPreview {
                    AddSeasonList(flow: flow, seasons: seasons,
                                  bars: [AddSeasonBar(tier: hdOn ? .hd : .uhd, label: "HD", preview: hdPreview)]
                                      + (uhdPreview.map { [AddSeasonBar(tier: .uhd, label: "4K", preview: $0)] } ?? []),
                                  disabled: split || flow.effectiveAnime,
                                  anime: flow.effectiveAnime && !split,
                                  customised: custom ? flow.seasonFrom : [:])
                } else if flow.previewLoading {
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in SkeletonBar(height: 26, radius: 8) }
                    }
                    .accessibilityLabel("Loading seasons")
                }
                VStack(alignment: .leading, spacing: 6) {
                    AddSummaryText(parts: custom && hdPreview != nil
                                   ? AddSentence.custom(hdPreview!, adjusted: flow.seasonFrom.count)
                                   : AddSentence.monitor(flow.monitor, preview: hdPreview, seasons: hasStrip ? seasons : nil),
                                   prefix: split ? "HD" : nil)
                    if split {
                        AddSummaryText(parts: AddSentence.monitor(uhdMonitor, preview: uhdPreview, seasons: hasStrip ? seasons : nil),
                                       prefix: "4K")
                    }
                    if hdOn && uhdOn {
                        Button(split ? "Same for both versions" : "Different for 4K") { setSplit(!split) }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.i2)
                            .frame(minHeight: 44)
                            .buttonStyle(.plain)
                    }
                }
                .font(.system(size: 13))
            }
            .padding(14)
            .addCard(look, radius: 14)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
        }
    }

    /// The master row: with split on it edits the HD version only.
    private func setMaster(_ mode: String) {
        let keep = uhdMonitor
        let wasSplit = split
        withAnimation(motion ? .easeOut(duration: 0.25) : nil) {
            flow.setMasterMonitor(mode)
            if wasSplit { flow.setTierMonitor(.uhd, keep) }
        }
    }

    private func setSplit(_ next: Bool) {
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            if next {
                // Custom seasons apply to the single row only: splitting drops them.
                flow.clearSeasonFrom()
                splitChosen = true
                editingRow = .uhd
            } else {
                splitChosen = false
                flow.setMasterMonitor(flow.monitor)
            }
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(selected ? Theme.bg : Theme.mut)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(Theme.txt).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct AddSeasonBar {
    let tier: QualityTier
    let label: String
    let preview: MonitorPreview
}
