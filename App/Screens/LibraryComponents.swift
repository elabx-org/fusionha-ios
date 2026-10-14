import SwiftUI
import FusionhaKit

/// A simple wrapping row (CSS `flex-wrap: wrap`).
struct LibraryWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Filters sheet

/// The "Filters" sheet: Recency, Group: Status, Sort and the coverage-rail
/// display (admins write it to Settings; others see why they can't).
struct LibraryFiltersSheet: View {
    @Environment(AppModel.self) private var model
    @Binding var recency: LibraryRecency
    @Binding var group: Bool
    @Binding var sort: LibrarySort

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Filters").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                section("Recency") {
                    SegmentedPills(options: [(LibraryRecency.all, "Any"), (.added, "Added"), (.released, "Released")],
                                   selection: $recency)
                }
                section("Group") {
                    Button {
                        group.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            if group { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                            Text("Group: Status").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(group ? Theme.i2 : Theme.txt)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(group ? Theme.i2.opacity(0.1) : Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(group ? Theme.i2 : Theme.line))
                    }
                    .buttonStyle(PressScaleStyle())
                }
                section("Sort") {
                    Picker("Sort", selection: $sort) {
                        ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.txt)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .panel(Theme.panel2, radius: 10)
                }
                section("Coverage rails") { railControls }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var railControls: some View {
        let isAdmin = model.me?.isAdmin == true
        VStack(alignment: .leading, spacing: 8) {
            ForEach(RailStyle.allCases, id: \.self) { style in
                Button {
                    Task { await model.updateRails(style: style) }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                            Text(style.hint).font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                        }
                        Spacer(minLength: 8)
                        RailRowView(rail: Rail(state: .owned, progress: 100, fraction: nil, attention: false, deadLinkOnly: false),
                                    tier: .hd, size: 12_800_000_000)
                            .environment(\.railStyle, style)
                            .frame(width: 110)
                    }
                    .padding(12)
                    .background(model.railStyle == style ? Theme.i2.opacity(0.08) : Theme.panel,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(model.railStyle == style ? Theme.i2.opacity(0.6) : Theme.line))
                }
                .buttonStyle(.plain)
                .disabled(!isAdmin)
            }
            Toggle(isOn: Binding(get: { model.railConsolidate },
                                 set: { value in Task { await model.updateRails(consolidate: value) } })) {
                Text("Consolidate HD + 4K").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
            }
            .tint(Theme.indigo)
            .disabled(!isAdmin)
            if !isAdmin {
                Text("Set by admin — only administrators can change the library coverage-rail display.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

// MARK: - Compact table (LibraryCompactTable.tsx)

private let tableEditionsWidth: CGFloat = 128
private let tableSizeWidth: CGFloat = 52
private let tableMonitorWidth: CGFloat = 36

struct LibraryTableHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Title ▾").frame(maxWidth: .infinity, alignment: .leading)
            Text("Versions · coverage").lineLimit(1).frame(width: tableEditionsWidth, alignment: .leading)
            Text("Size").frame(width: tableSizeWidth, alignment: .trailing)
            Color.clear.frame(width: tableMonitorWidth)
        }
        .font(.system(size: 10.5, weight: .bold))
        .tracking(0.7)
        .textCase(.uppercase)
        .foregroundStyle(Theme.mut)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(Theme.panel, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
        .overlay(TableBorder(top: true, bottom: false))
    }
}

struct LibraryTableRow: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    let last: Bool

    private var profileNames: String {
        let ids = item.editions.compactMap(\.qualityProfileId)
        var seen = Set<Int>()
        let unique = ids.filter { seen.insert($0).inserted }
        return unique.map { id in model.profileName(id) ?? "#\(id)" }.joined(separator: " · ")
    }

    var body: some View {
        let monitored = item.monitored ?? true
        Button { model.open(item.id) } label: {
            HStack(spacing: 8) {
                HStack(spacing: 9) {
                    PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                        .frame(width: 34, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                        Text(subline).font(.system(size: 11.5)).foregroundStyle(Theme.mut).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CoverageRails(item: item, inline: true, spacing: 5)
                    .frame(width: tableEditionsWidth, alignment: .leading)
                Text(Format.bytes(item.totalSize))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
                    .frame(width: tableSizeWidth, alignment: .trailing)
                Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14))
                    .foregroundStyle(monitored ? Theme.i2 : Theme.mut.opacity(0.5))
                    .frame(width: tableMonitorWidth)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(TableRowStyle())
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1).padding(.horizontal, 1) }
        }
        .overlay(TableBorder(top: false, bottom: last))
        .contextMenu { PosterActions(item: item) }
        .reveal(0, y: 7, duration: 0.38)
    }

    private var subline: String {
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        parts.append(item.kind == .movie ? "Movie" : "Series")
        if item.isAnime == true { parts.append("Anime") }
        let profiles = profileNames
        if !profiles.isEmpty { parts.append(profiles) }
        return parts.joined(separator: " · ")
    }
}

private struct TableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Theme.txt.opacity(configuration.isPressed ? 0.04 : 0))
    }
}

/// The table's outer hairline, drawn per row so the rows stay lazy.
private struct TableBorder: View {
    let top: Bool
    let bottom: Bool

    var body: some View {
        TableBorderShape(top: top, bottom: bottom, radius: 14)
            .stroke(Theme.line, lineWidth: 1)
    }
}

private struct TableBorderShape: Shape {
    let top: Bool
    let bottom: Bool
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.5, dy: 0)
        var p = Path()
        if top {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
            p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
            p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius,
                     startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        } else if bottom {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - radius))
            p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                     startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: r.maxX - radius, y: r.maxY))
            p.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius,
                     startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        }
        return p
    }
}

// MARK: - Bulk action bar (BulkActionBar.tsx)

/// The glass bar that replaces the tab bar in select mode: the count, "of N
/// filtered", Select all / Clear / Done, and the bulk actions once something
/// is selected.
struct BulkActionBar: View {
    @Environment(AppModel.self) private var model
    let visibleIds: [Int]
    @State private var profiles: [QualityProfile] = []
    @State private var showingRoot = false
    @State private var confirmingDelete = false

    var body: some View {
        let count = model.selection.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(count) selected").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                if !visibleIds.isEmpty {
                    Text("of \(visibleIds.count) filtered").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !visibleIds.isEmpty && count < visibleIds.count {
                    ghost("Select all \(visibleIds.count)") { model.selection = Set(visibleIds) }
                }
                if count > 0 { ghost("Clear") { model.selection = [] } }
                ghost("Done", strong: true) { model.exitSelectMode() }
            }
            if count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        action("Monitor", "bookmark") {
                            model.bulk(nil, "Couldn't update the selection") { client, ids in
                                try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: true))
                            }
                        }
                        action("Unmonitor", "bookmark.slash") {
                            model.bulk(nil, "Couldn't update the selection") { client, ids in
                                try await client.bulkMonitor(BulkMonitorRequest(itemIds: ids, monitored: false))
                            }
                        }
                        action("Refresh & Scan", "arrow.clockwise") {
                            let n = count
                            model.bulk("Queued Refresh & Scan for \(n) \(n == 1 ? "item" : "items")", "Couldn't queue the refresh") { client, ids in
                                try await client.bulkRefresh(BulkRefreshRequest(itemIds: ids, metadataOnly: false))
                            }
                        }
                        Menu {
                            ForEach(profiles) { profile in
                                Button(profile.name) {
                                    model.bulk(nil, "Couldn't set the quality profile") { client, ids in
                                        try await client.bulkQualityProfile(BulkQualityProfileRequest(itemIds: ids, qualityProfileId: profile.id))
                                    }
                                }
                            }
                        } label: { chip("Quality Profile", "slider.horizontal.3", menu: true) }
                        Menu {
                            ForEach(AvailabilityOption.allCases, id: \.self) { option in
                                Button(option.label) { setAvailability(option) }
                            }
                        } label: { chip("Minimum availability", "calendar", menu: true) }
                        action("Change root…", "folder") { showingRoot = true }
                        Button { confirmingDelete = true } label: {
                            chip("Delete", "trash", danger: true)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .scrollClipDisabled()
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 11)
        .padding(.bottom, 11)
        .background {
            Rectangle()
                .fill(Color(red: 18 / 255, green: 20 / 255, blue: 27 / 255).opacity(0.94))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.6), radius: 12, y: -8)
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .task { profiles = (try? await model.client?.qualityProfiles()) ?? [] }
        .sheet(isPresented: $showingRoot) {
            ChangeRootSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .confirmationDialog("Delete \(count) \(count == 1 ? "title" : "titles")?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.bulk(nil, "Couldn't delete the selection") { client, ids in
                    try await client.bulkDelete(BulkDeleteRequest(itemIds: ids, deleteFiles: false))
                }
                model.selection = []
            }
        } message: {
            Text("This removes the selected titles and all their versions from your library. Files stay on disk.")
        }
    }

    private func setAvailability(_ option: AvailabilityOption) {
        let ids = Array(model.selection)
        guard let client = model.client else { return }
        Task {
            do {
                let result = try await client.bulkMinimumAvailability(
                    BulkMinimumAvailabilityRequest(itemIds: ids, minimumAvailability: option))
                let n = result.affected ?? ids.count
                model.toast("Set minimum availability on \(n) \(n == 1 ? "movie" : "movies")")
                await model.loadLibrary()
            } catch {
                model.toast("Couldn't set minimum availability", variant: .error)
            }
        }
    }

    private func ghost(_ title: String, strong: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: strong ? .bold : .semibold))
                .foregroundStyle(strong ? Theme.i2 : Theme.txt)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 9)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
    }

    private func action(_ title: String, _ symbol: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { chip(title, symbol) }
            .buttonStyle(PressScaleStyle())
    }

    private func chip(_ title: String, _ symbol: String, menu: Bool = false, danger: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(title).font(.system(size: 12.5, weight: .semibold))
            if menu { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.mut) }
        }
        .foregroundStyle(danger ? Theme.danger : Theme.txt)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// ChangeRootPopover: re-assign the selection's root folder per tier.
private struct ChangeRootSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var tier = "all"
    @State private var roots: [RootFolder] = []
    @State private var rootId: Int?
    @State private var disposition: RootFileDisposition = .move

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Re-assign root folder").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            field("Which versions to move") {
                SegmentedPills(options: [("HD-1080p", "HD·1080p"), ("UHD-2160p", "UHD·4K"), ("all", "Every version")],
                               selection: $tier, fill: true)
            }
            field("New root folder") {
                Picker("New root folder", selection: $rootId) {
                    Text("Choose…").tag(Int?.none)
                    ForEach(roots) { Text($0.path).tag(Int?.some($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(Theme.txt)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .panel(Theme.panel2, radius: 10)
            }
            field("Existing files") {
                SegmentedPills(options: RootFileDisposition.allCases.map { ($0, $0.label) }, selection: $disposition, fill: true)
            }
            Spacer(minLength: 0)
            Button {
                guard let rootId else { return }
                let tier = self.tier, disposition = self.disposition
                model.bulk("Root folder updated", "Couldn't change the root folder") { client, ids in
                    try await client.bulkRootFolder(BulkRootFolderRequest(itemIds: ids, tier: tier, rootFolderId: rootId,
                                                                          disposition: disposition))
                }
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.fusion, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(rootId == nil)
            .opacity(rootId == nil ? 0.5 : 1)
        }
        .padding(20)
        .task { roots = (try? await model.client?.rootFolders()) ?? [] }
    }

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
    }
}
