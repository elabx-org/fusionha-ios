import SwiftUI
import FusionhaKit

/// Report an issue in v2's form sheet (Look Pass family 1). The fields and
/// rules are v1's `IssueModal`: what's wrong as glass choice chips (the one
/// chosen in the accent), the versions as rows with their media badge, the
/// part as a segmented picker with Season and Episode menus, the note, and
/// the footer line. The sheet keeps the state; this only draws it.
struct V2IssueForm: View {
    let isSeries: Bool
    let seasons: [Int: Int]?
    let versions: [IssueVersionRef]
    let needVersion: Bool
    @Binding var problem: String
    @Binding var versionId: Int?
    @Binding var picked: Bool
    @Binding var scope: String
    @Binding var season: Int?
    @Binding var episode: Int?
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                V2FormLabel(text: "What’s wrong?")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(IssueFormat.problems(series: isSeries), id: \.value) { p in chip(p) }
                }
                .sensoryFeedback(.selection, trigger: problem)
            }
            versionSection
            if isSeries { partSection }
            VStack(alignment: .leading, spacing: 7) {
                V2FormLabel(text: "Anything else?", hint: "Optional")
                V2FormCard {
                    TextField("Tell us what you saw…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 16))
                        .v2FormRow()
                }
                Text("You can report once per problem and version.")
                    .font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func chip(_ p: IssueFormat.Problem) -> some View {
        let on = problem == p.value
        return Button { problem = p.value } label: {
            HStack(spacing: 8) {
                Image(systemName: p.symbol).font(.system(size: 14, weight: .semibold))
                Text(p.label).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private var versionSection: some View {
        if versions.count > 1 {
            VStack(alignment: .leading, spacing: 7) {
                V2FormLabel(text: "Which version?", hint: versions.count == 2 ? "You can see both" : "You can see \(versions.count)")
                V2FormCard {
                    ForEach(Array(versions.enumerated()), id: \.offset) { index, v in
                        if index > 0 { V2FormDivider() }
                        if let id = v.id, let tier = v.tier { versionRow(id: id, tier: tier, edition: v.edition) }
                    }
                }
                .sensoryFeedback(.selection, trigger: versionId)
                if needVersion && versionId == nil {
                    Text("Pick the version you mean.").font(.system(size: 13)).foregroundStyle(Theme.dangerText)
                        .padding(.horizontal, 4)
                }
            }
        } else if versions.count == 1, let tier = versions[0].tier {
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 12))
                Text("This title has one version you can report on:")
                EditionBadge(tier: tier, state: .onDisk, showsCount: false)
            }
            .font(.system(size: 13)).foregroundStyle(Theme.mut)
            .padding(.horizontal, 4)
        }
    }

    private func versionRow(id: Int, tier: QualityTier, edition: String?) -> some View {
        let on = versionId == id
        return Button { versionId = id; picked = true } label: {
            HStack(spacing: 12) {
                EditionBadge(tier: tier, state: .onDisk, showsCount: false)
                Text(IssueFormat.versionText(tier: tier, edition: edition))
                    .font(.system(size: 16, weight: on ? .semibold : .regular))
                    .foregroundStyle(Theme.txt)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accentText)
                }
            }
            .v2FormRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private var partSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            V2FormLabel(text: "Which part?")
            Picker("Which part?", selection: $scope) {
                Text("Whole show").tag("item")
                Text("A season").tag("season")
                Text("One episode").tag("episode")
            }
            .pickerStyle(.segmented)
            .onChange(of: scope) {
                if scope == "item" { season = nil; episode = nil }
                else if season == nil { season = seasons?.keys.sorted().first }
                if scope != "episode" { episode = nil }
            }
            if scope != "item" {
                V2FormCard {
                    seasonRow
                    if scope == "episode" {
                        V2FormDivider()
                        episodeRow
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seasonRow: some View {
        if let seasons, !seasons.isEmpty {
            V2FormPickerRow(title: "Season", selection: $season) {
                Text("Select…").tag(Int?.none)
                ForEach(seasons.keys.sorted(), id: \.self) { n in Text(n == 0 ? "Specials" : "Season \(n)").tag(Int?.some(n)) }
            }
            .onChange(of: season) { episode = nil }
        } else {
            TextField("Season", value: $season, format: .number).keyboardType(.numberPad)
                .font(.system(size: 16)).v2FormRow()
        }
    }

    @ViewBuilder
    private var episodeRow: some View {
        if let seasons, let n = season, let count = seasons[n], count > 0 {
            V2FormPickerRow(title: "Episode", selection: $episode) {
                Text("Select…").tag(Int?.none)
                ForEach(1...count, id: \.self) { e in Text("Episode \(e)").tag(Int?.some(e)) }
            }
        } else {
            TextField("Episode", value: $episode, format: .number).keyboardType(.numberPad)
                .font(.system(size: 16)).v2FormRow()
        }
    }
}

/// The issue sheet's heading in v2: the large title, then the title's poster,
/// name and year, and its versions as media badges.
struct V2IssueHeader: View {
    let title: String
    let year: Int?
    let poster: String?
    let tiers: [QualityTier]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            V2SheetHeading(title: "Report an issue")
            HStack(spacing: 12) {
                ActPoster(url: poster, title: title, size: .sm)
                VStack(alignment: .leading, spacing: 5) {
                    (Text(title).fontWeight(.semibold) + Text(verbatim: year.map { " (\($0))" } ?? "").foregroundColor(Theme.mut))
                        .font(.system(size: 17)).foregroundStyle(Theme.txt)
                    if !tiers.isEmpty {
                        EditionTicketPair(hd: tiers.contains(.hd) ? .onDisk : nil,
                                          uhd: tiers.contains(.uhd) ? .onDisk : nil, showsCount: false)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
