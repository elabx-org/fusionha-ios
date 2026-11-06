import SwiftUI
import FusionhaKit

/// Grab a release fusionha passed over (mock browse-sheets.js
/// `grabDecision`, the static decision page): the release, the problem in
/// plain words, what fusionha does if nothing changes, then the choices.
/// Keeping the current file (or choice) is the primary action; Grab anyway is v1's
/// grab (a blocklisted release grabs with the override that lifts it).
struct V2GrabAnywaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let release: ReleasePreview
    let model: InteractiveSearchModel
    /// The problem when it isn't the server's: a group blocked since the search.
    var problemOverride: String? = nil

    private var blocklisted: Bool { release.blocklisted == true }
    private var edition: DetailEdition? { model.edition }
    /// The version already has a file this grab would replace on import.
    private var replaces: Bool {
        guard let edition, let detail = model.store.detail else { return false }
        if let episodeId = model.target.episodeId {
            return detail.allEpisodes.first { $0.id == episodeId }?.file(for: edition.id) != nil
        }
        return detail.fileCount(edition) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Kit `.decide`: the question and its lines on one W1 card.
                    VStack(alignment: .leading, spacing: 10) {
                        Text(blocklisted ? "Grab a blocklisted release?" : "Grab a release fusionha skipped?")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.txt)
                            .accessibilityAddTraits(.isHeader)
                        line("Release", release.title, sub: facts)
                        line("The problem", problem)
                        line("Fusionha will", plan)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background { ModuleSurface(radius: 20) }
                    choices
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Grab anyway?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton(title: "Close") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var choices: some View {
        VStack(spacing: 8) {
            Button { dismiss() } label: {
                Label(replaces ? "Keep current file" : "Keep the current choice", systemImage: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.i1)
            Button {
                Task { await model.grab(release) }
                dismiss()
            } label: {
                Label(grabTitle, systemImage: "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glass)
        }
    }

    private func line(_ key: String, _ text: String, sub: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .frame(width: 92, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.system(size: 13.5)).lineSpacing(3).foregroundStyle(Theme.txt)
                if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(Theme.mut) }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var facts: String {
        let parts: [String?] = [release.quality, release.size.map { DetailText.bytes($0) }, ReleaseSearch.indexer(release),
                                ReleaseSearch.score(release.cfScore ?? 0)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    private var problem: String {
        if let problemOverride { return problemOverride }
        if blocklisted { return release.blocklistReason ?? "It is on the blocklist, so fusionha never grabs it." }
        return release.reason.map { V2GrabAnywaySheet.sentence($0) } ?? "It does not meet this version's rules."
    }

    private var plan: String {
        replaces
            ? "Skip it and keep the current file. Nothing changes unless you choose otherwise."
            : "Skip it and keep looking on every RSS sync and search. Nothing changes unless you choose otherwise."
    }

    private var grabTitle: String {
        if blocklisted { return "Grab anyway and lift the blocklist" }
        guard let edition, replaces else { return "Grab anyway" }
        return "Grab anyway, replace \(edition.tier.badgeLetters) on import"
    }

    /// "not an upgrade" → "Not an upgrade."
    static func sentence(_ reason: String) -> String {
        guard let first = reason.first else { return reason }
        let text = first.uppercased() + reason.dropFirst()
        return text.hasSuffix(".") ? text : text + "."
    }
}
