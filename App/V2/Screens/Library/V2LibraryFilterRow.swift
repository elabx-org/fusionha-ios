import SwiftUI
import FusionhaKit

/// The Library's chip row (v2 header, mock browse.js home 'live'): one
/// sideways row of glass chips over the existing filters, no new semantics.
/// All clears the version, status and service filters; HD / 4K are the tier; Missing
/// and Upcoming the status filter; Service the network (`V2LibraryServiceChip`);
/// Anime the kind. A chip tapped again turns
/// off. The rest of the filters live in the bar's Filter menu
/// (`V2LibraryFilterMenu`); set ones show as tokens under this row.
struct V2LibraryFilterRow: View {
    let filters: V2LibraryFilters
    /// The library has anime (the Anime chip's kind).
    var showsAnime = true
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    /// The library's services for the Service chip, rebuilt when the library changes.
    @State private var services: [V2LibraryService] = []

    private var anime: Bool { filters.kind == LibraryKind.anime.rawValue }
    private var feedbackKey: String { "\(filters.tier.rawValue)|\(filters.status.rawValue)|\(filters.kind)|\(filters.network)" }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip("All", on: filters.tier == .all && filters.status == .all && filters.network.isEmpty) {
                        filters.tier = .all
                        filters.status = .all
                        filters.network = ""
                    }
                    chip("HD", on: filters.tier == .hd) { filters.tier = filters.tier == .hd ? .all : .hd }
                    chip("4K", on: filters.tier == .uhd) { filters.tier = filters.tier == .uhd ? .all : .uhd }
                    chip("Missing", on: filters.status == .missing) { toggle(.missing) }
                    if !services.isEmpty || !filters.network.isEmpty {
                        V2LibraryServiceChip(filters: filters, services: services)
                    }
                    if showsAnime || anime {
                        chip("Anime", symbol: "sparkle", on: anime) {
                            filters.kind = anime ? "all" : LibraryKind.anime.rawValue
                        }
                    }
                    chip("Upcoming", symbol: "clock", on: filters.status == .upcoming) { toggle(.upcoming) }
                }
            }
        }
        .scrollClipDisabled()
        .task(id: "\(model.libraryVersion)|\(filters.network)") {
            let next = V2LibraryServices.from(model.library, keeping: filters.network)
            if next != services { services = next }
        }
        #if DEBUG
        // CI screenshots: `FUSIONHA_SCREENSHOT_NETWORK=<name>` picks that service.
        .onAppear {
            if let name = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_NETWORK"] { filters.network = name }
        }
        #endif
        .sensoryFeedback(.selection, trigger: feedbackKey)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filters")
    }

    private func toggle(_ status: LibraryStatus) {
        filters.status = filters.status == status ? .all : status
    }

    /// kit `.chip` (34 high, 13.5pt): plain glass, or the accent when on
    /// (selection is one of the accent's three jobs).
    private func chip(_ title: String, symbol: String? = nil, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(motion ? .snappy : nil) { action() }
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.txt)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.primary).interactive() : .regular.interactive(), in: Capsule())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
