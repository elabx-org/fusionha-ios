import SwiftUI
import FusionhaKit

/// The Details card (web `DetailsCard`, phone layout): one grouped list —
/// Identified as, Series type and Metadata (series), and Folder — with the
/// Settings → Default profiles note under it. A choice row shows its value and
/// expands in place into option rows, one row open at a time.
struct AddDetailsCard: View {
    let flow: AddFlow
    @State private var openRow: String?
    @Environment(\.motionEnabled) private var motion
    @Environment(\.addLook) private var look

    private static let seriesTypes: [(value: String, label: String, note: String, icon: String)] = [
        ("standard", "Standard", "Season and episode numbers", "list.number"),
        ("daily", "Daily", "Dated episodes (talk shows, news)", "calendar"),
        ("anime", "Anime", "Absolute numbering, anime profiles", "paintbrush.pointed"),
    ]
    private static let providerNames = AddProviderValue.names
    private static let providers = ["auto", "tmdb", "tvdb", "tvmaze", "hybrid"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                AddIdsRow(flow: flow)
                if flow.isSeries {
                    divider
                    choiceRow(key: "type", label: "Series type",
                              tag: flow.detectedAnime ? "Detected: anime" : nil,
                              options: Self.seriesTypes.map { ($0.value, $0.label, $0.note as String?) },
                              value: flow.seriesType, icon: { value in
                                  Image(systemName: Self.seriesTypes.first { $0.value == value }?.icon ?? "list.number")
                                      .font(.system(size: 13, weight: .semibold))
                                      .frame(width: 18)
                              }, onChange: { flow.seriesType = $0 }) {
                        HStack(spacing: 6) {
                            Image(systemName: Self.seriesTypes.first { $0.value == flow.seriesType }?.icon ?? "list.number")
                                .font(.system(size: 12, weight: .semibold))
                            Text(Self.seriesTypes.first { $0.value == flow.seriesType }?.label ?? flow.seriesType)
                        }
                    }
                    divider
                    if flow.showProviderChoice {
                        choiceRow(key: "meta", label: "Metadata", tag: nil,
                                  options: Self.providers.map { p -> (String, String, String?) in
                                      (p, Self.providerNames[p] ?? p,
                                       p == "auto" ? "Your default (\(Self.providerNames[flow.defaultProvider] ?? flow.defaultProvider))"
                                           : p == "hybrid" ? "TMDB details, TVDB numbering" : nil)
                                  },
                                  value: flow.provider, iconOnly: ["tmdb", "tvdb", "tvmaze"], icon: { value in
                                      AddProviderLogo(provider: value, size: 18)
                                  }, onChange: { flow.provider = $0 }) {
                            if flow.provider == "auto" {
                                HStack(spacing: 5) {
                                    Text("Automatic →")
                                    AddProviderValue(provider: flow.defaultProvider)
                                }
                            } else {
                                AddProviderValue(provider: flow.provider)
                            }
                        }
                    } else {
                        // A TVDB-only pick has no choice: the row names what builds it.
                        HStack(spacing: 10) {
                            Text("Metadata").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer(minLength: 8)
                            AddProviderValue(provider: flow.effectiveProvider)
                                .font(.system(size: 13.5))
                                .foregroundStyle(Theme.mut)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                    }
                }
                divider
                AddFolderRow(flow: flow)
            }
            .addCard(look, radius: 14)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
            Text("Defaults from Settings → Default profiles")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim)
                .padding(.leading, 2)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }

    private func choiceRow<Icon: View, Value: View>(
        key: String, label: String, tag: String?, options: [(String, String, String?)], value: String,
        iconOnly: Set<String> = [], @ViewBuilder icon: @escaping (String) -> Icon, onChange: @escaping (String) -> Void,
        @ViewBuilder phoneValue: () -> Value
    ) -> some View {
        let open = openRow == key
        return VStack(spacing: 0) {
            Button {
                withAnimation(motion ? .snappy(duration: 0.28) : nil) { openRow = open ? nil : key }
            } label: {
                HStack(spacing: 10) {
                    Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let tag {
                        Text(tag.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(Theme.anime)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.anime.opacity(0.4)))
                    }
                    Spacer(minLength: 8)
                    phoneValue()
                        .font(.system(size: 13.5))
                        .foregroundStyle(open ? Theme.i2 : Theme.mut)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(options.first { $0.0 == value }?.1 ?? value)
            .accessibilityHint(open ? "Collapse" : "Show the choices")
            if open {
                VStack(spacing: 0) {
                    ForEach(options, id: \.0) { option in
                        let on = option.0 == value
                        Button {
                            onChange(option.0)
                            withAnimation(motion ? .snappy(duration: 0.28) : nil) { openRow = nil }
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        icon(option.0)
                                        // A wordmark spells its own name: logo-only, like the web.
                                        if !iconOnly.contains(option.0) {
                                            Text(option.1)
                                                .font(.system(size: 14, weight: on ? .semibold : .regular))
                                        }
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(option.1)
                                    .foregroundStyle(on ? Theme.i2 : Theme.txt)
                                    if let note = option.2 {
                                        Text(note).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                                    }
                                }
                                Spacer(minLength: 8)
                                if on {
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.i2)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 26)
                            .padding(.trailing, 14)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.bottom, 6)
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}
