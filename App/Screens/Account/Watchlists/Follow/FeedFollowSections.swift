import SwiftUI
import FusionhaKit

/// The address flow's sections (web `FeedFollowPanel`): the address field
/// with its message or hint, Works with (or the Recognised line), Preview;
/// once previewed, the preview, Versions, What's on it now, and the note
/// that requests go the normal way.
struct FeedFollowSections: View {
    @Environment(AppModel.self) private var model
    @Bindable var feed: FeedFollowModel
    let uhdAllowed: Bool

    var body: some View {
        Section {
            TextField(FeedCopy.placeholder, text: $feed.url)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { if feed.canPreview() { feed.runPreview(model.client) } }
                .accessibilityLabel(FeedCopy.label)
            if feed.shown == nil {
                FollowPreviewButton(reading: feed.reading, ready: feed.ready, nextAt: feed.nextPreviewAt) {
                    feed.runPreview(model.client)
                }
            }
        } header: {
            Text(FeedCopy.label)
        } footer: {
            footer
        }
        if let preview = feed.shown, let url = feed.previewed {
            FeedPreviewSection(preview: preview, url: url)
            versions(letterboxd: preview.site == .letterboxd)
            FeedStartSection(existing: $feed.existing, count: preview.itemCount)
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = feed.message {
                Label {
                    Text(message.text) + Text(message.tip.map { " " + $0 } ?? "").foregroundStyle(Theme.mut)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(Theme.danger)
                .accessibilityAddTraits(.isStaticText)
            } else if feed.isPlex {
                Text(FeedCopy.plexLaterHint)
            }
            if feed.shown == nil { WorksWithRow() }
        }
    }

    @ViewBuilder
    private func versions(letterboxd: Bool) -> some View {
        Section(FeedCopy.versions) {
            if letterboxd {
                Text(FeedCopy.lbVersions).font(.footnote).foregroundStyle(Theme.mut)
            } else {
                LabeledContent {
                    Text(FeedCopy.hdAlways).foregroundStyle(Theme.mut)
                } label: {
                    TierPill(tier: .hd, large: true)
                }
                Toggle(isOn: $feed.uhd) {
                    HStack(alignment: .top, spacing: 10) {
                        TierPill(tier: .uhd, large: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FeedCopy.uhdSwitch).foregroundStyle(Theme.txt)
                            Text(uhdAllowed ? FeedCopy.uhdYes : FeedCopy.uhdNo).font(.caption).foregroundStyle(Theme.mut)
                        }
                    }
                }
                .disabled(!uhdAllowed)
            }
        }
    }
}

/// "Works with": the three sites the box accepts, and Plex coming later.
struct WorksWithRow: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { items }
            VStack(alignment: .leading, spacing: 6) { items }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var items: some View {
        Text(FeedCopy.worksWith).font(.caption).foregroundStyle(Theme.mut)
        ProviderChip(provider: .mdblist)
        ProviderChip(provider: .trakt)
        ProviderChip(provider: .letterboxd)
        ProviderChip(provider: .plex, text: FeedCopy.plexLater).opacity(0.6)
    }
}

/// "What's on it now": only new additions (recommended) or also what's on it.
struct FeedStartSection: View {
    @Binding var existing: Bool
    let count: Int?

    var body: some View {
        Section {
            Picker(FeedCopy.now, selection: $existing) {
                choice(FeedCopy.newOnly + " (recommended)", FeedCopy.newOnlyDesc(count)).tag(false)
                choice(FeedCopy.existing, FeedCopy.existingDesc(count)).tag(true)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text(FeedCopy.now)
        } footer: {
            Text(FeedCopy.normalLead).bold() + Text(" " + FeedCopy.normalRest)
        }
    }

    private func choice(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(desc).font(.caption).foregroundStyle(Theme.mut)
        }
    }
}
