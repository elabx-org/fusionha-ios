import SwiftUI
import FusionhaKit

/// "Add a Letterboxd source" (web `AddSourcePanel`): a list by address or
/// someone's watchlist by username, a 25-film preview (30 s apart), the
/// baseline, then Add. The server decides what is valid; the local check only
/// enables Preview, and Add sends exactly what was previewed.
struct AddSourceSheet: View {
    enum Kind: String, Hashable { case list, watchlist }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let store: WatchlistsStore
    let linkedAfter: Int
    let max: Int
    @State private var kind: Kind = .list
    @State private var url = ""
    @State private var username = ""
    @State private var error: String?
    @State private var preview: LbSourcePreview?
    @State private var previewed: LbSourceTarget?
    @State private var existing = false
    @State private var nextPreviewAt: Date?
    @State private var reading = false
    @State private var adding = false

    private var target: LbSourceTarget {
        kind == .list ? .list(url: url.trimmingCharacters(in: .whitespaces)) : .watchlist(username: username)
    }

    private var ready: Bool {
        kind == .list ? LetterboxdLogic.looksLikeListURL(url) : LetterboxdLogic.validUsername(username)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("What to add", selection: $kind) {
                        Text("A list (paste URL)").tag(Kind.list)
                        Text("Someone’s public watchlist").tag(Kind.watchlist)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text(kind == .list ? "Anyone’s public list, yours or someone else’s." : "A partner’s or a critic’s, by username.")
                }
                Section {
                    field
                    previewButton
                } footer: {
                    Text(error ?? hint).foregroundStyle(error == nil ? Theme.mut : Theme.danger)
                }
                if let preview, previewed != nil {
                    AddSourcePreviewRows(preview: preview, existing: $existing)
                    Section {
                        Button(kind == .list ? "Add list" : "Add watchlist") { add() }
                            .disabled(adding)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Add a Letterboxd source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
            }
            .onChange(of: kind) { reset() }
            .onChange(of: url) { reset() }
            .onChange(of: username) { reset() }
        }
        .presentationDragIndicator(.visible)
    }

    private var hint: String {
        kind == .list
            ? "Paste the address of a public list. Anything that isn’t a letterboxd.com list address is refused."
            : "Their watchlist must be public. fusionha can’t verify who owns a username; it only reads public pages."
    }

    @ViewBuilder
    private var field: some View {
        if kind == .list {
            TextField("https://letterboxd.com/name/list/best-of-2026/", text: $url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Letterboxd list address")
        } else {
            HStack(spacing: 2) {
                Text("letterboxd.com/").foregroundStyle(Theme.dim)
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Username whose watchlist to follow")
            }
        }
    }

    private var previewButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = nextPreviewAt.map { Swift.max(0, Int($0.timeIntervalSince(context.date).rounded(.up))) } ?? 0
            HStack {
                Button { runPreview() } label: {
                    if reading {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Reading…") }
                    } else {
                        Label("Preview", systemImage: "magnifyingglass")
                    }
                }
                .disabled(!ready || reading || left > 0)
                if left > 0 {
                    Spacer()
                    Text("You can preview again in \(left) s").font(.caption).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    private func reset() {
        preview = nil
        previewed = nil
        error = nil
    }

    private func runPreview() {
        guard let client = model.client else { return }
        let sent = target
        error = nil
        reading = true
        Task {
            defer { reading = false }
            do {
                let result = try await client.previewRequestSource(sent)
                // A late answer for an older input is dropped.
                guard sent == target else { return }
                preview = result
                previewed = sent
                nextPreviewAt = Date().addingTimeInterval(30)
            } catch {
                guard sent == target else { return }
                if let at = (error as? APIError)?.retryAt { nextPreviewAt = ServerTime.parse(at) }
                preview = nil
                self.error = WatchlistErrorCopy.letterboxdMessage(for: error, watchlist: kind == .watchlist)
            }
        }
    }

    private func add() {
        guard let client = model.client, let previewed else { return }
        let existing = existing
        adding = true
        Task {
            defer { adding = false }
            do {
                _ = try await client.addRequestSource(previewed, enabled: true, requestExisting: existing)
                model.toast(LetterboxdLogic.addedToast(linkedAfter, max: max))
                await store.load(client)
                dismiss()
            } catch {
                self.error = WatchlistErrorCopy.letterboxdMessage(for: error, watchlist: kind == .watchlist)
            }
        }
    }
}

/// The preview: title, film count, the 25-film sample with in-library marks,
/// and the baseline choice.
private struct AddSourcePreviewRows: View {
    let preview: LbSourcePreview
    @Binding var existing: Bool

    var body: some View {
        Section {
            ForEach(Array(preview.items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.title).foregroundStyle(item.inLibrary ? Theme.mut : Theme.txt)
                    if let year = item.year { Text(String(year)).foregroundStyle(Theme.dim) }
                    Spacer(minLength: 8)
                    if item.inLibrary { Text("in library").font(.caption).foregroundStyle(Theme.done) }
                }
                .font(.subheadline)
            }
        } header: {
            HStack {
                Text(preview.title ?? "@\(preview.owner ?? "") · watchlist")
                Spacer()
                if let count = preview.itemCount { Text("\(count) films") }
            }
        } footer: {
            Text("By @\(preview.owner ?? ""). Showing a sample of 25. fusionha reads the full list once you add it.")
        }
        Section("What to request") {
            Picker("What to request", selection: $existing) {
                VStack(alignment: .leading) {
                    Text("Only new additions (recommended)")
                    Text("What’s on it now is noted and left alone.").font(.caption).foregroundStyle(Theme.mut)
                }
                .tag(false)
                VStack(alignment: .leading) {
                    Text("Also request what’s already on it")
                    Text("A few at a time, within your weekly limit.").font(.caption).foregroundStyle(Theme.mut)
                }
                .tag(true)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}
