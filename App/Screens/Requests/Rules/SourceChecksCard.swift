import SwiftUI
import FusionhaKit

/// The Rules lane's "Plex watchlist checks" and "Letterboxd & list checks"
/// (web `PlexWatchlistChecksCard` + `LetterboxdChecksCard`, fusionha 0.4.209 /
/// 0.4.213): how often opted-in people's watchlists, diaries and linked lists
/// are read, and how many new titles one check may request. Admin-only,
/// saved field by field and applied on the next tick, no restart.
struct SourceChecksCard: View {
    @Environment(AppModel.self) private var model
    @State private var values: [String: Int] = [:]
    @State private var plexPeople: Int?
    @State private var letterboxd: LetterboxdStats?

    private var isAdmin: Bool { model.me?.isAdmin ?? false }

    private func value(_ key: String, _ fallback: Int) -> Int { values[key] ?? fallback }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            plexSection
            Divider().overlay(Theme.line)
            letterboxdSection
            if !isAdmin { Text(SourceChecksCopy.adminOnly).font(.caption).foregroundStyle(Theme.dim) }
        }
        .padding(14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .disabled(!isAdmin)
        .task { await load() }
    }

    private var plexSection: some View {
        let minutes = value(SourceChecksCopy.intervalKey, 10)
        return VStack(alignment: .leading, spacing: 10) {
            heading("PLEX WATCHLIST CHECKS", "How often fusionha reads opted-in people’s Plex watchlists. Changes apply on the next tick, no restart.")
            Stepper {
                row("Check each watchlist \(SourceChecksCopy.humanInterval(minutes))",
                    "Spread out so checks never all fire at once. Range 5 minutes to 1 day.")
            } onIncrement: {
                save(SourceChecksCopy.intervalKey, minutes - 5, in: SourceChecksCopy.intervalRange)
            } onDecrement: {
                save(SourceChecksCopy.intervalKey, minutes + 5, in: SourceChecksCopy.intervalRange)
            }
            .accessibilityHint("Increment checks more often, decrement less often")
            Picker("Preset", selection: Binding(get: { minutes }, set: { save(SourceChecksCopy.intervalKey, $0, in: SourceChecksCopy.intervalRange) })) {
                if !SourceChecksCopy.presets.contains(minutes) { Text("\(minutes) min").tag(minutes) }
                ForEach(SourceChecksCopy.presets, id: \.self) { Text(SourceChecksCopy.presetLabel($0)).tag($0) }
            }
            if let plexPeople {
                Text(SourceChecksCopy.estimateLine(people: plexPeople, minutes: minutes)).font(.caption).foregroundStyle(Theme.mut)
            }
            intStepper(SourceChecksCopy.maxNewKey, fallback: 10, range: SourceChecksCopy.maxNewRange,
                       title: "New titles per check: \(value(SourceChecksCopy.maxNewKey, 10))",
                       sub: "Most titles one check may request for a single person. The rest wait for the next check. Applies to every automatic source, Letterboxd included.")
        }
    }

    private var letterboxdSection: some View {
        let diary = value(SourceChecksCopy.diaryKey, 6)
        let lists = value(SourceChecksCopy.listsKey, 6)
        return VStack(alignment: .leading, spacing: 10) {
            heading("LETTERBOXD & LIST CHECKS", "How often fusionha reads Letterboxd diaries and linked lists. Changes apply on the next tick, no restart.")
            intStepper(SourceChecksCopy.diaryKey, fallback: 6, range: SourceChecksCopy.hoursRange,
                       title: "Read each diary every \(SourceChecksCopy.hoursWord(diary))",
                       sub: "RSS is cheap and reliable. Spread out so reads never all fire at once.")
            intStepper(SourceChecksCopy.listsKey, fallback: 6, range: SourceChecksCopy.hoursRange,
                       title: "Check linked lists every \(SourceChecksCopy.hoursWord(lists))",
                       sub: "Letterboxd lists and followed watchlists are scraped, so they are read at most every 12 hours whatever this says.")
            if let letterboxd {
                Text(SourceChecksCopy.letterboxdEstimateLine(people: letterboxd.connectedUsers, sources: letterboxd.linkedSources, diaryHours: diary))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
        }
    }

    private func heading(_ title: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
            Text(note).font(.footnote).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
            Text(sub).font(.caption).foregroundStyle(Theme.mut).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func intStepper(_ key: String, fallback: Int, range: ClosedRange<Int>, title: String, sub: String) -> some View {
        let current = value(key, fallback)
        return Stepper {
            row(title, sub)
        } onIncrement: {
            save(key, current + 1, in: range)
        } onDecrement: {
            save(key, current - 1, in: range)
        }
    }

    // MARK: Load and save

    private func load() async {
        guard let client = model.client else { return }
        if let settings = try? await client.settings() { absorb(settings) }
        plexPeople = (try? await client.watchlistStats())?.optedInUsers
        letterboxd = try? await client.letterboxdStats()
    }

    private func absorb(_ settings: [String: JSONValue]) {
        for key in [SourceChecksCopy.intervalKey, SourceChecksCopy.maxNewKey, SourceChecksCopy.diaryKey, SourceChecksCopy.listsKey] {
            if let n = settings[key]?.int { values[key] = n }
        }
    }

    /// Optimistic: shows the clamped value at once, rolls back if the server refuses.
    private func save(_ key: String, _ raw: Int, in range: ClosedRange<Int>) {
        let next = min(range.upperBound, max(range.lowerBound, raw))
        let before = values[key]
        guard next != before, let client = model.client else { return }
        values[key] = next
        Task {
            do {
                absorb(try await client.updateSettings([key: .number(Double(next))]))
            } catch {
                values[key] = before
                model.toast(ErrorCopy.message(for: error, fallback: "Couldn’t save the change."), variant: .error)
            }
        }
    }
}
