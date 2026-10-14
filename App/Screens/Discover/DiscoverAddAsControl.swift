import SwiftUI

/// Discover's "Add as" provider override (the web's `DiscoverBrowseControls`
/// provider note): "Add as [mark] ⌄", opening a dropdown of
/// Default (X) / TMDB / TVDB / Hybrid. TMDB and TVDB are logo-only, Hybrid is
/// the ring mark beside its name. A native `Menu` flattens custom label views
/// (no chips, no drawn mark), so the list is a popover of custom rows.
struct DiscoverAddAsControl: View {
    @State private var session = DiscoverSession.shared
    @State private var open = false

    static func name(_ value: String) -> String {
        switch value {
        case "tvdb": return "TVDB"
        case "hybrid": return "Hybrid"
        default: return "TMDB"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Add as").foregroundStyle(Theme.dim)
            Button { open = true } label: {
                HStack(spacing: 6) {
                    ProviderMark(provider: session.effectiveProvider, size: 11)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                }
                .padding(.horizontal, 2)
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Metadata provider for new adds")
            .accessibilityValue(Self.name(session.effectiveProvider))
            .popover(isPresented: $open, arrowEdge: .top) {
                DiscoverAddAsMenu(selection: session.providerOverride,
                                  globalName: Self.name(session.globalProvider)) { value in
                    session.providerOverride = value
                    open = false
                }
                .presentationCompactAdaptation(.popover)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.mut)
        #if DEBUG
        .task { await screenshotOpen() }
        #endif
    }

    #if DEBUG
    /// `FUSIONHA_SCREENSHOT_DISCOVER_ADDAS=<auto|tmdb|tvdb|hybrid>` picks that
    /// override, then `…_ADDAS_OPEN=1` opens the dropdown.
    private func screenshotOpen() async {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["FUSIONHA_SCREENSHOT_DISCOVER_ADDAS"] else { return }
        if ["auto", "tmdb", "tvdb", "hybrid"].contains(raw) { session.providerOverride = raw }
        guard env["FUSIONHA_SCREENSHOT_DISCOVER_ADDAS_OPEN"] == "1" else { return }
        try? await Task.sleep(for: .seconds(2))
        open = true
    }
    #endif
}

/// The dropdown's rows: a check for the current choice, then the option.
private struct DiscoverAddAsMenu: View {
    let selection: String
    let globalName: String
    let pick: (String) -> Void

    private static let options = ["auto", "tmdb", "tvdb", "hybrid"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.options, id: \.self) { value in
                Button { pick(value) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                            .opacity(value == selection ? 1 : 0)
                            .frame(width: 16)
                        option(value)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: 200, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == "auto" ? "Default (\(globalName))" : DiscoverAddAsControl.name(value))
                .accessibilityAddTraits(value == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func option(_ value: String) -> some View {
        if value == "auto" {
            Text("Default (\(globalName))")
                .font(.system(size: 14))
                .foregroundStyle(Theme.txt)
        } else {
            ProviderMark(provider: value, size: 13)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.txt)
        }
    }
}
