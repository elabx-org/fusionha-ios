import SwiftUI
import FusionhaKit

/// The open Duo's right page while files are ticked (mock bulk, inner):
/// "4 selected · E1, E2, E6, E13", what bulk can do with them, ① the files'
/// choice as radios (Fusionha's picks first, only where the server gives
/// them), ② the download when the pack is done, then Confirm match, Import
/// mode and Edit N as glass chips. "Apply to 4" stages the choice onto the
/// page; the footer applies everything.
struct V2MIBulkPanel: View {
    @Environment(ManualImportSession.self) private var session
    @Environment(V2MIDraftStore.self) private var store
    @Environment(\.pagePalette) private var page
    @State private var option: V2MIBulkOption?
    @State private var editing = false

    var body: some View {
        let b = session.bulk
        let chosen = option ?? defaultOption
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(b.n) selected").font(.system(size: 17, weight: .bold)).foregroundStyle(page?.ink ?? Theme.txt)
                    Spacer(minLength: 8)
                    Text(ManualImportBulk.codeList(b.lines.map(\.code))).font(.footnote).foregroundStyle(Theme.mut).lineLimit(1)
                }
                Text(helper(b))
                    .font(.system(size: 12.5))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
                DecisionStep(number: 1, title: "Files", tone: .accent, dense: true)
                MIChoiceList(options: options, chosen: choice(chosen), pick: store.tickedPicks(session) > 0 ? .rematch : nil,
                             dense: true) { c in option = Self.option(c) }
                if !b.dispositions.isEmpty {
                    DecisionStep(number: 2, title: "The download, when this pack is done", tone: .muted, dense: true)
                    Picker("Download", selection: Binding(get: { store.disposition ?? b.preferred },
                                                           set: { store.disposition = $0 })) {
                        ForEach(b.dispositions) { Text(MIDownloadDispositionMenu.short($0.value)).tag($0.value) }
                    }
                    .pickerStyle(.segmented)
                }
                chips(b)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .goBarInset {
            GoBar(label: applyLabel(chosen, b), systemImage: "checkmark",
                  disabled: !store.bulkLabel(chosen, session).enabled) {
                store.stage(option: chosen, session)
                option = nil
            }
        }
        .onChange(of: session.selected) { option = nil }
        .duoPageSheet(isPresented: $editing) {
            MIBulkSheet(title: "Edit \(b.open.count) selected", rows: b.open).environment(session)
        }
    }

    /// Fusionha's picks when any ticked file has one, else Import, else Keep, else Skip.
    private var defaultOption: V2MIBulkOption {
        V2MIBulkOption.allCases.first { store.bulkLabel($0, session).enabled } ?? .skip
    }

    /// The radios reuse the choice list; the picks row rides on `.rematch` as its key
    /// (tagged Fusionha's pick, the others as overrides, as on the cards).
    private var options: [MIChoiceList.Option] {
        V2MIBulkOption.allCases.compactMap { o -> MIChoiceList.Option? in
            let l = store.bulkLabel(o, session)
            guard l.enabled else { return nil }
            return MIChoiceList.Option(choice: choice(o), title: l.title, detail: l.detail)
        }
    }

    private func choice(_ o: V2MIBulkOption) -> MIChoice {
        switch o {
        case .picks: return .rematch
        case .importFile: return .importFile
        case .keep: return .keep
        case .skip: return .skip
        }
    }

    private static func option(_ c: MIChoice) -> V2MIBulkOption {
        switch c {
        case .rematch: return .picks
        case .importFile, .assign: return .importFile
        case .keep: return .keep
        case .skip: return .skip
        }
    }

    private func helper(_ b: ManualImportBulkSummary) -> String {
        if let note = b.decidedNote { return note }
        return b.imp.count < b.open.count
            ? "Bulk import never replaces a better copy, so \(b.imp.isEmpty ? "none of these import" : "only \(b.of(b.imp.count)) can import")."
            : "All \(b.n) can import in place."
    }

    private func applyLabel(_ o: V2MIBulkOption, _ b: ManualImportBulkSummary) -> String {
        o == .importFile ? "Apply to \(b.n) · import \(b.imp.count)" : "Apply to \(b.n)"
    }

    private func chips(_ b: ManualImportBulkSummary) -> some View {
        @Bindable var session = session
        return GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                let confirm = session.tickedToConfirm
                if !confirm.isEmpty {
                    Button("Confirm match", systemImage: "checkmark") { Task { await session.confirm(confirm) } }
                }
                Menu {
                    Picker("Import mode", selection: $session.importMode) {
                        ForEach(ManualImportMode.allCases) { Text("\($0.label) · \($0.hint)").tag($0) }
                    }
                } label: {
                    Label("Import mode · \(session.importMode.label)", systemImage: "arrow.left.arrow.right")
                }
                Button("Edit \(b.open.count)…", systemImage: "pencil") { editing = true }
                    .disabled(b.open.isEmpty)
            }
            .buttonStyle(.glass)
            .font(.system(size: 13.5, weight: .semibold))
        }
    }
}
