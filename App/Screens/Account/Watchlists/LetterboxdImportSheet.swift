import SwiftUI
import UniformTypeIdentifiers
import FusionhaKit

/// The one-time import (web `OneTimeImportModal`): pick `watchlist.csv` or the
/// export ZIP → paced matching (the token is kept, so closing the sheet
/// doesn't lose it) → preview → commit → done. An expired preview asks for
/// the file again.
struct LetterboxdImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fusionha.lb-import-token") private var token = ""
    let onCommitted: () -> Void
    @State private var preview: CsvPreviewRead?
    @State private var picking = false
    @State private var uploading = false
    @State private var committing = false
    @State private var error: String?
    @State private var done: CsvCommitResult?
    @State private var have = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Backfill a private watchlist from your Letterboxd export. Up to 1 MB and 5,000 rows.")
                        .font(.footnote).foregroundStyle(Theme.mut)
                }
                if let error {
                    Section { WatchlistAttention(lead: error, rest: "") }
                }
                content
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("One-time import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .zip, .plainText]) { result in
                if case .success(let url) = result { upload(url) }
            }
            .task(id: token) { await poll() }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        if let done {
            Section {
                WatchlistInfo(icon: "checkmark.circle", lead: "Imported.", rest: LetterboxdLogic.importDone(done, have: have))
                Button("Import another file", systemImage: "square.and.arrow.up") { reset() }
            }
        } else if token.isEmpty {
            Section {
                Button { picking = true } label: {
                    if uploading {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Uploading…") }
                    } else {
                        Label("Choose a file", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(uploading)
            } footer: {
                Text("On Letterboxd: Settings → Import & Export → Export your data, then pick watchlist.csv from the zip (or upload the whole zip). Up to 1 MB and 5,000 rows. Films already handled are skipped if you import again.")
            }
        } else if let preview, preview.status == "FAILED" {
            Section {
                WatchlistAttention(lead: preview.error == "no_tmdb"
                                   ? "Matching needs a TMDB key. Ask an admin to add one, then upload the file again."
                                   : "This preview expired. Upload the file again.", rest: "")
                Button("Import another file", systemImage: "square.and.arrow.up") { reset() }
            }
        } else if let preview, preview.status == "READY", preview.counts != nil {
            LetterboxdImportPreview(preview: preview, busy: committing, onCommit: commit, onCancel: reset)
        } else {
            Section {
                let total = preview?.total ?? 0
                let doneCount = preview?.done ?? 0
                VStack(alignment: .leading, spacing: 8) {
                    Text("Matching \(doneCount) of \(total) films to TMDB…").fontWeight(.semibold)
                    ProgressView(value: Double(doneCount), total: Double(Swift.max(total, 1)))
                    Text("Matching is paced so TMDB isn’t flooded. You can close this panel; the preview waits for you.")
                        .font(.caption).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    // MARK: Actions

    private func reset() {
        token = ""
        preview = nil
        done = nil
        error = nil
    }

    private func upload(_ url: URL) {
        guard let client = model.client else { return }
        error = nil
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            error = "Couldn’t read that file."
            return
        }
        let name = url.lastPathComponent
        if APIClient.letterboxdFileTooLarge(name: name, size: data.count) {
            error = "That file is too big. The limit is 1 MB (10 MB for the export ZIP)."
            return
        }
        uploading = true
        Task {
            defer { uploading = false }
            do {
                let started = try await client.uploadLetterboxdExport(data, filename: name)
                token = started.previewToken
            } catch {
                self.error = Self.uploadMessage(error)
            }
        }
    }

    /// Polls the preview every second while it matches.
    private func poll() async {
        guard !token.isEmpty, let client = model.client else { return }
        let current = token
        while !Task.isCancelled, current == token {
            do {
                let read = try await client.letterboxdImportPreview(token: current)
                preview = read
                if read.status != "MATCHING" { return }
            } catch let failure as APIError where failure.code == "not_found" {
                reset()
                return
            } catch {}
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func commit(_ requestNow: Int, _ includeLow: [String]) {
        guard let client = model.client, !token.isEmpty else { return }
        let current = token
        have = preview?.counts?.alreadyHave ?? 0
        committing = true
        Task {
            defer { committing = false }
            do {
                done = try await client.commitLetterboxdImport(token: current, requestNow: requestNow,
                                                              includeLowConfidence: includeLow)
                token = ""
                onCommitted()
            } catch {
                self.error = WatchlistErrorCopy.letterboxdMessage(for: error)
            }
        }
    }

    static func uploadMessage(_ error: Error) -> String {
        if let at = (error as? APIError)?.retryAt {
            let seconds = Swift.max(1, WatchlistTime.secondsLeft(at))
            return "You just imported a file. Try again in \(seconds) seconds."
        }
        return WatchlistErrorCopy.letterboxdMessage(for: error)
    }
}
