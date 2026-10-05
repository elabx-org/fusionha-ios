import SwiftUI
import UIKit
import FusionhaKit

/// The Details card (web `DetailsCard`, phone layout): one grouped list —
/// Identified as, Series type and Metadata (series), and Folder — with the
/// Settings → Default profiles note under it. A choice row shows its value and
/// expands in place into option rows, one row open at a time.
struct AddDetailsCard: View {
    let flow: AddFlow
    @State private var openRow: String?
    @Environment(\.motionEnabled) private var motion

    private static let seriesTypes: [(value: String, label: String, note: String, icon: String)] = [
        ("standard", "Standard", "Season and episode numbers", "list.number"),
        ("daily", "Daily", "Dated episodes (talk shows, news)", "calendar"),
        ("anime", "Anime", "Absolute numbering, anime profiles", "sparkles"),
    ]
    private static let providerNames: [String: String] = [
        "auto": "Automatic", "tmdb": "TMDB", "tvdb": "TVDB", "tvmaze": "TVmaze", "hybrid": "Hybrid",
    ]
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
                                  value: flow.provider, icon: { value in
                                      if value != "auto" { ProviderLogo(provider: value, compact: true) }
                                  }, onChange: { flow.provider = $0 }) {
                            if flow.provider == "auto" {
                                HStack(spacing: 5) {
                                    Text("Automatic →")
                                    ProviderLogo(provider: flow.defaultProvider, compact: true)
                                }
                            } else {
                                ProviderLogo(provider: flow.provider, compact: true)
                            }
                        }
                    } else {
                        // A TVDB-only pick has no choice: the row names what builds it.
                        HStack(spacing: 10) {
                            Text("Metadata").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer(minLength: 8)
                            ProviderLogo(provider: flow.effectiveProvider, compact: true)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                    }
                }
                divider
                AddFolderRow(flow: flow)
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        @ViewBuilder icon: @escaping (String) -> Icon, onChange: @escaping (String) -> Void,
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
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
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
                                        Text(option.1)
                                            .font(.system(size: 14, weight: on ? .semibold : .regular))
                                    }
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

/// "Identified as": one copy-to-clipboard chip per known id.
private struct AddIdsRow: View {
    let flow: AddFlow
    @State private var copied: String?

    var body: some View {
        let ids = flow.ids
        var chips: [(String, String)] = []
        if let tmdb = ids.tmdb { chips.append(("TMDB", String(tmdb))) }
        if let tvdb = ids.tvdb { chips.append(("TVDB", String(tvdb))) }
        if let imdb = ids.imdb, !imdb.isEmpty { chips.append(("IMDb", imdb)) }
        // While the preview loads, hold the space of the ids it usually brings.
        let pending = flow.previewLoading
            ? (flow.isSeries ? [ids.tvdb == nil, (ids.imdb ?? "").isEmpty] : [(ids.imdb ?? "").isEmpty]).filter { $0 }.count
            : 0
        return Group {
            if !chips.isEmpty || pending > 0 {
                // The chips wrap under the label on a phone.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Identified as").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    PreviewFlow(spacing: 6) {
                        ForEach(chips, id: \.0) { chip in
                            Button { copy(chip.0, chip.1) } label: {
                                (Text(chip.0).fontWeight(.bold).foregroundColor(Theme.txt)
                                 + Text(" " + (copied == chip.0 ? "Copied" : chip.1)))
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(copied == chip.0 ? Theme.i2 : Theme.mut)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .frame(minHeight: 36)
                                    .background(Theme.txt.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.line))
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityLabel("Copy \(chip.0) id \(chip.1)")
                        }
                        ForEach(0..<pending, id: \.self) { _ in
                            SkeletonBar(height: 30, radius: 7).frame(width: 74)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .sensoryFeedback(.success, trigger: copied)
            }
        }
    }

    private func copy(_ name: String, _ value: String) {
        UIPasteboard.general.string = value
        copied = name
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if copied == name { copied = nil }
        }
    }
}

/// "Folder": the folder name (renames inline — sent only when it differs from
/// the default) and one Plex-ready path per enabled version, the
/// `{edition-…}` token in the variant colour. A 409 collision washes the row
/// amber and reopens the field.
private struct AddFolderRow: View {
    let flow: AddFlow
    @State private var editing = false
    @State private var before = ""
    @FocusState private var focused: Bool

    private var conflict: String? { flow.error?.folder == true ? flow.error?.message : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Folder").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                if !flow.onTiers.isEmpty {
                    if editing {
                        TextField("", text: Binding(get: { flow.folderName }, set: { flow.setFolderName($0) }),
                                  prompt: Text(flow.derivedFolder).foregroundStyle(Theme.dim))
                            .font(.system(size: 13.5, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focused)
                            .onSubmit { editing = false }
                            .padding(.horizontal, 10)
                            .frame(height: 36)
                            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(conflict != nil ? Theme.miss.opacity(0.6) : Theme.line))
                        iconButton("checkmark", label: "Done renaming") { editing = false }
                    } else {
                        Spacer(minLength: 8)
                        Text(flow.shownFolder)
                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.txt)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        iconButton("pencil", label: "Rename folder") {
                            before = flow.folderName
                            editing = true
                        }
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            if flow.onTiers.isEmpty {
                if flow.ready {
                    Text("Turn on a version to see where it goes.")
                        .font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .padding(.horizontal, 14).padding(.bottom, 12)
                } else {
                    SkeletonBar(height: 14, radius: 5).padding(.horizontal, 14).padding(.bottom, 12)
                }
            }
            ForEach(flow.onTiers, id: \.self) { tier in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(tier.pill)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(tier.color)
                    path(tier)
                        .font(.system(size: 12, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            if let conflict {
                Text(conflict)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(conflict != nil ? Theme.miss.opacity(0.1) : .clear)
        .onChange(of: conflict) { if conflict != nil { editing = true } }
        .onChange(of: editing) { focused = editing }
    }

    private func path(_ tier: QualityTier) -> Text {
        let root = flow.roots?.first { $0.id == flow.versions?[tier]?.rootId }?.path ?? ""
        var trimmed = root
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let edition = flow.editions[tier]
        var text = Text(trimmed + "/").foregroundColor(Theme.dim) + Text(flow.shownFolder).foregroundColor(Theme.txt)
        if !AddVocab.isStandardEdition(edition), let edition {
            text = text + Text(" {edition-\(edition)}").foregroundColor(Theme.anime)
        }
        return text
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
