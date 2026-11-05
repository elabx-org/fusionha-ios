import SwiftUI
import FusionhaKit

/// The top of Manual Import (owner's top-section diet): the poster, title
/// and pack in one line, the hold's reason in one line with More (v1's held
/// strip), and one helper line.
struct V2MIHeader: View {
    var helps = true
    @Environment(ManualImportSession.self) private var session
    @Environment(\.pagePalette) private var page
    @State private var more = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                PosterImage(url: TMDBImage.resized(session.rows.first?.match.posterUrl, to: "w154"))
                    .frame(width: 32, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            if let held {
                Button { more.toggle() } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.stuckText)
                        Text("Held: \(held)  ").foregroundColor(page?.ink ?? Theme.txt)
                            + Text(more ? "Less" : "More").foregroundColor(Theme.primary).fontWeight(.semibold)
                    }
                    .font(.system(size: 13.5))
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 9)
                .accessibilityHint(more ? "Hides why it is held" : "Shows why it is held")
                if more, let strip {
                    MIHeldStripView(strip: strip).padding(.top, 8)
                }
            }
            if helps {
                Text("Change a group, or open it to change single files.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    private var strip: ManualImportHeldStrip? {
        session.scan.flatMap { ManualImportHeldStrip(scan: $0, decide: session.plan.need, tallies: session.tallies) }
    }

    /// The hold in one line: the strip's first line, else the server's reason.
    private var held: String? {
        if let line = strip?.lines(compact: true).line1, !line.isEmpty { return line.joined(separator: " · ") }
        return session.scan?.heldReason
    }

    /// "The Office (US) · Season 5", or the title alone.
    private var title: String {
        let rows = session.rows
        let name = rows.first.flatMap { $0.match.title ?? $0.parsed.title } ?? "Manual Import"
        let seasons = Set(rows.filter { $0.target.isSeries }.compactMap { $0.target.season ?? $0.parsed.season })
        guard rows.first?.target.isSeries == true, seasons.count == 1, let season = seasons.first else { return name }
        return "\(name) · Season \(season)"
    }

    /// "EPSiLON Remux pack · 26 files · 131 GB".
    private var subtitle: String {
        let rows = session.rows
        let first = rows.first
        let release = MIProblemCopy.releaseName(first?.parsed.releaseGroup, first?.quality)
        let files = rows.count == 1 ? "1 file" : "\(rows.count) files"
        let lead = release.isEmpty ? nil : rows.count > 1 ? "\(release) pack" : release
        return [lead, files, DetailText.bytes(rows.reduce(0) { $0 + $1.size })].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Groups | Files, then the chips over what the files do ("All 26",
/// "Import 23", "Keep 2", "Skip 1"): glass controls, the selected chip in the accent.
struct V2MIControls: View {
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let c = store.counts(session)
        let open = session.rows.filter { !$0.committed }.count
        VStack(alignment: .leading, spacing: 10) {
            Picker("View", selection: $store.segment) {
                ForEach(V2MIDraftStore.Segment.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        chip("All \(open)", .all)
                        if c.imports > 0 { chip("Import \(c.imports)", .imports) }
                        if c.keeps > 0 { chip("Keep \(c.keeps)", .keeps) }
                        if c.skips > 0 { chip("Skip \(c.skips)", .skips) }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .onChange(of: store.segment) { session.selected = [] }
    }

    private func chip(_ title: String, _ filter: V2MIDraftStore.Filter) -> some View {
        let on = store.filter == filter
        return Button(title) { store.filter = on ? .all : filter }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: .capsule)
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}
